class CreateGithubItems < ActiveRecord::Migration
  def change
    create_table :github_items do |t|
      t.text :event
      t.references :user

      t.timestamps
    end
  end
end
