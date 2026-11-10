require "fileutils"
require "open3"
require "tempfile"

# Respaldo diario de la base de datos primaria (SRS RNF-05).
# Ejecuta pg_dump (formato custom) y sube el volcado a S3 bajo backups/.
# Las bases cache, queue y cable son desechables y no se respaldan.
class DatabaseBackupJob < ApplicationJob
  queue_as :default

  # Un fallo transitorio (S3 o base de datos) no debe perder el respaldo del día.
  # Tras el último intento el error se vuelve a lanzar y queda en los jobs fallidos.
  retry_on StandardError, wait: 10.minutes, attempts: 3

  def perform
    unless Rails.env.production?
      Rails.logger.info "[Respaldo] Omitido: solo se ejecuta en producción."
      return
    end

    database = ENV.fetch("DB_NAME") { "legal_docs_aps_production" }
    key = "backups/#{database}-#{Time.now.utc.strftime("%Y%m%dT%H%M%SZ")}.dump"
    bucket = backup_bucket
    env = pg_env

    tmp_dir = Rails.root.join("tmp")
    FileUtils.mkdir_p(tmp_dir)
    file = Tempfile.new([ "respaldo", ".dump" ], tmp_dir.to_s, binmode: true)
    begin
      file.close
      dump(env, database, file.path)
      upload(bucket, key, file.path)
    ensure
      file.close!
    end

    Rails.logger.info "[Respaldo] Respaldo subido a s3://#{bucket}/#{key}"
    key
  end

  private

  def backup_bucket
    ENV["AWS_S3_BACKUP_BUCKET"].presence || ENV["AWS_S3_BUCKET"].presence ||
      raise("Respaldo fallido: defina AWS_S3_BACKUP_BUCKET o AWS_S3_BUCKET.")
  end

  def dump(env, database, path)
    command = [ "pg_dump", "-Fc", "--no-password", "-f", path, database ]
    _stdout, stderr, status = run_command(env, command)
    return if status.success?

    raise "Respaldo fallido: pg_dump terminó con error (código #{status.exitstatus}): #{stderr.to_s.strip}"
  end

  def pg_env
    password = ENV["DIGITALLAW_DATABASE_PASSWORD"].presence ||
      raise("Respaldo fallido: defina DIGITALLAW_DATABASE_PASSWORD.")

    env = {
      "PATH" => ENV["PATH"].to_s,
      "PGPORT" => ENV.fetch("DB_PORT") { "5432" }.to_s,
      "PGUSER" => ENV.fetch("DB_USER") { "legal_docs_aps" },
      "PGPASSWORD" => password
    }
    env["PGHOST"] = ENV["DB_HOST"] if ENV["DB_HOST"].present?
    env
  end

  # Ejecuta sin shell y con entorno limpio (no hereda secretos como
  # AWS_SECRET_ACCESS_KEY ni RAILS_MASTER_KEY); devuelve [stdout, stderr, status].
  def run_command(env, command)
    Open3.capture3(env, *command, unsetenv_others: true)
  end

  def upload(bucket, key, path)
    File.open(path, "rb") do |io|
      s3_client.put_object(bucket: bucket, key: key, body: io)
    end
  rescue StandardError => e
    raise "Respaldo fallido: no se pudo subir a S3 (#{e.class}): #{e.message}"
  end

  def s3_client
    options = {
      region: ENV.fetch("AWS_REGION") { "us-east-1" },
      access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"]
    }
    if ENV["AWS_S3_ENDPOINT"].present?
      options[:endpoint] = ENV["AWS_S3_ENDPOINT"]
      options[:force_path_style] = true
    end
    Aws::S3::Client.new(**options)
  end
end
