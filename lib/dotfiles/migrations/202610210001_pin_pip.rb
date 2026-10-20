class Dotfiles::Migration::PinPip < Dotfiles::Migration
  VERSION = 202610210001

  def up
    return unless command_exists?("mise")

    execute(command("mise", "--cd", @home, "exec", "--", "python", "-m", "pip", "install", "--upgrade", "pip==26.2.2"))
  end

  def down
    raise NotImplementedError, "This migration upgrades pip and cannot be safely reversed."
  end
end
