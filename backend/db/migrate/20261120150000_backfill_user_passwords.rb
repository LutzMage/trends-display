# WARNING: This migration does not reflect the best practice. Instead, it is just a solution for tis POC.
# Every user needs a password (SPEC-002). Existing users get one shared password from the environment.
class BackfillUserPasswords < ActiveRecord::Migration[8.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  def up
    clashes = select_values("SELECT LOWER(TRIM(email)) FROM users GROUP BY 1 HAVING COUNT(*) > 1")
    raise "These emails differ only by case; fix them before migrating: #{clashes.join(', ')}" if clashes.any?

    execute "UPDATE users SET email = LOWER(TRIM(email))"

    pending = MigrationUser.where(password_digest: nil)
    if pending.exists?
      password = ENV["DEFAULT_USER_PASSWORD"]
      raise "Set DEFAULT_USER_PASSWORD in backend/.env before running this migration" if password.blank?

      pending.update_all(password_digest: BCrypt::Password.create(password))
    end

    change_column_null :users, :password_digest, false
  end

  def down
    change_column_null :users, :password_digest, true
  end
end
