class Document < ApplicationRecord
  belongs_to :firm
  belongs_to :user
end
