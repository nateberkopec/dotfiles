class SetupSSHKeysStep < Step
  def should_run?
    if ci_or_noninteractive?
      debug "Skipping 1Password SSH key setup in CI/non-interactive environment"
      return false
    end
    !complete?
  end

  def run
    debug "1Password CLI found, unlocking SSH key..."

    unless signed_in?
      execute('op signin --account "my.1password.com"', quiet: false)
    end

    # TODO: is this still required?
    ssh_key_json = execute('op item get "Main SSH Key (id_rsa)" --format=json', capture_output: true)
    ssh_key_data = JSON.parse(ssh_key_json)
    private_key = ssh_key_data["fields"].find { |f| f["label"] == "private key" }["value"]

    IO.popen("ssh-add - 2>/dev/null", "w") { |io| io.write(private_key) }
  end

  def complete?
    return true if ci_or_noninteractive?
    command_exists?("op") && signed_in?
  end

  private

  def signed_in?
    system("op whoami >/dev/null 2>&1")
  end
end
