require "test_helper"

class DatabaseBackupJobTest < ActiveSupport::TestCase
  FakeStatus = Struct.new(:ok, :exitstatus) do
    def success? = ok
  end

  class FakeS3
    attr_reader :calls

    def initialize(error: nil)
      @calls = []
      @error = error
    end

    def put_object(**args)
      raise @error if @error
      @calls << args.merge(content: args[:body].read)
    end
  end

  ENV_KEYS = %w[DB_NAME DB_HOST DB_PORT DB_USER DIGITALLAW_DATABASE_PASSWORD
                AWS_S3_BACKUP_BUCKET AWS_S3_BUCKET].freeze

  setup do
    @saved_env = ENV.to_h.slice(*ENV_KEYS)
    ENV["DB_NAME"] = "legal_test_db"
    ENV["DB_HOST"] = "db.example"
    ENV["DB_PORT"] = "5432"
    ENV["DB_USER"] = "backup_user"
    ENV["DIGITALLAW_DATABASE_PASSWORD"] = "s3cr3t-pass"
    ENV["AWS_S3_BACKUP_BUCKET"] = "bucket-respaldos"
    ENV["AWS_S3_BUCKET"] = "bucket-archivos"
    @runs = []
    @paths = []
    @s3 = FakeS3.new
  end

  teardown do
    ENV_KEYS.each { |k| ENV.delete(k) }
    @saved_env.each { |k, v| ENV[k] = v }
  end

  test "no hace nada fuera de produccion" do
    job = build_job(status: FakeStatus.new(true, 0))
    job.perform
    assert_empty @runs
    assert_empty @s3.calls
  end

  test "ejecuta pg_dump sin contrasena en argumentos y sube a S3" do
    job = build_job(status: FakeStatus.new(true, 0), write: "contenido-dump")
    key = in_production { job.perform }

    env, command = @runs.first
    assert_kind_of Array, command
    assert_equal "pg_dump", command.first
    assert_includes command, "-Fc"
    assert_includes command, "legal_test_db"
    assert_not command.any? { |arg| arg.include?("s3cr3t-pass") }
    assert_equal "s3cr3t-pass", env["PGPASSWORD"]
    assert_equal "db.example", env["PGHOST"]
    assert_equal "5432", env["PGPORT"]
    assert_equal "backup_user", env["PGUSER"]

    call = @s3.calls.first
    assert_equal "bucket-respaldos", call[:bucket]
    assert_match(%r{\Abackups/legal_test_db-\d{8}T\d{6}Z\.dump\z}, call[:key])
    assert_equal key, call[:key]
    assert_equal "contenido-dump", call[:content]
  end

  test "usa AWS_S3_BUCKET si no hay bucket de respaldos" do
    ENV.delete("AWS_S3_BACKUP_BUCKET")
    job = build_job(status: FakeStatus.new(true, 0))
    in_production { job.perform }
    assert_equal "bucket-archivos", @s3.calls.first[:bucket]
  end

  test "falla con stderr si pg_dump falla y no sube nada" do
    job = build_job(status: FakeStatus.new(false, 1), stderr: "conexion rechazada")
    error = assert_raises(RuntimeError) { in_production { job.perform } }
    assert_includes error.message, "conexion rechazada"
    assert_not_includes error.message, "s3cr3t-pass"
    assert_empty @s3.calls
  end

  test "falla con mensaje claro si la subida falla" do
    @s3 = FakeS3.new(error: StandardError.new("acceso denegado"))
    job = build_job(status: FakeStatus.new(true, 0))
    error = assert_raises(RuntimeError) { in_production { job.perform } }
    assert_includes error.message, "no se pudo subir a S3"
    assert_includes error.message, "acceso denegado"
  end

  test "el archivo temporal se elimina tras un respaldo exitoso" do
    job = build_job(status: FakeStatus.new(true, 0))
    in_production { job.perform }
    path = @paths.first
    assert path.start_with?(Rails.root.join("tmp").to_s)
    assert_not File.exist?(path)
  end

  test "el archivo temporal se elimina si pg_dump falla" do
    job = build_job(status: FakeStatus.new(false, 1), stderr: "error")
    assert_raises(RuntimeError) { in_production { job.perform } }
    assert_not File.exist?(@paths.first)
  end

  test "falla con mensaje claro si no hay ningun bucket" do
    ENV.delete("AWS_S3_BACKUP_BUCKET")
    ENV["AWS_S3_BUCKET"] = ""
    job = build_job(status: FakeStatus.new(true, 0))
    error = assert_raises(RuntimeError) { in_production { job.perform } }
    assert_includes error.message, "AWS_S3_BACKUP_BUCKET"
    assert_empty @runs
    assert_empty @s3.calls
  end

  test "falla sin ejecutar pg_dump si la contrasena esta vacia" do
    ENV["DIGITALLAW_DATABASE_PASSWORD"] = ""
    job = build_job(status: FakeStatus.new(true, 0))
    error = assert_raises(RuntimeError) { in_production { job.perform } }
    assert_includes error.message, "DIGITALLAW_DATABASE_PASSWORD"
    assert_empty @runs
    assert_empty @s3.calls
  end

  test "omite PGHOST si DB_HOST esta vacio" do
    ENV["DB_HOST"] = ""
    job = build_job(status: FakeStatus.new(true, 0))
    in_production { job.perform }
    env, _command = @runs.first
    assert_not env.key?("PGHOST")
  end

  test "el entorno de pg_dump incluye PATH" do
    job = build_job(status: FakeStatus.new(true, 0))
    in_production { job.perform }
    env, _command = @runs.first
    assert_equal ENV["PATH"], env["PATH"]
    assert_not env.key?("AWS_SECRET_ACCESS_KEY")
  end

  private

  def in_production
    original = Rails.env
    Rails.env = ActiveSupport::EnvironmentInquirer.new("production")
    yield
  ensure
    Rails.env = original
  end

  def build_job(status:, stderr: "", write: "dump")
    job = DatabaseBackupJob.new
    runs = @runs
    paths = @paths
    s3 = @s3
    job.define_singleton_method(:run_command) do |env, command|
      runs << [ env, command ]
      path = command[command.index("-f") + 1]
      paths << path
      File.write(path, write)
      [ "", stderr, status ]
    end
    job.define_singleton_method(:s3_client) { s3 }
    job
  end
end
