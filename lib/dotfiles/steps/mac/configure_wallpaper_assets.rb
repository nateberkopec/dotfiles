module Dotfiles::Step::ConfigureWallpaperAssets
  private

  def wallpaper_query
    wallpaper_settings.fetch("query", "woodblock print")
  end

  def wallpaper_orientation
    wallpaper_settings.fetch("orientation", "landscape")
  end

  def wallpaper_hour
    wallpaper_settings.fetch("hour", 5)
  end

  def wallpaper_minute
    wallpaper_settings.fetch("minute", 0)
  end

  def wallpaper_settings
    @config.fetch("wallpaper_settings", {}) || {}
  end

  def script_content
    <<~FISH
      #!/usr/bin/env fish

      set -gx PATH "$HOME/.local/bin" "$HOME/.homebrew/bin" /opt/homebrew/bin /usr/local/bin /usr/bin /bin /usr/sbin /sbin $PATH

      set -l private_fish "$HOME/.config/fish/private.fish"
      if test -f "$private_fish"
        source "$private_fish"
      end

      for name in UNSPLASH_CLIENT_ID UNSPLASH_CLIENT_SECRET
        if not set -q $name
          echo "$name must be set, for example in ~/.config/fish/private.fish" >&2
          exit 1
        end
      end

      if not command -q splash
        echo "splash command not found; run dotf run to install splash-cli" >&2
        exit 1
      end

      command splash --plain --query "#{wallpaper_query}" --orientation "#{wallpaper_orientation}" --no-cache $argv
    FISH
  end

  def plist_content
    <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>Label</key>
          <string>#{launchagent_label}</string>
          <key>ProgramArguments</key>
          <array>
              <string>#{find_fish_path}</string>
              <string>#{script_path}</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>StartCalendarInterval</key>
          <dict>
              <key>Hour</key>
              <integer>#{wallpaper_hour}</integer>
              <key>Minute</key>
              <integer>#{wallpaper_minute}</integer>
          </dict>
          <key>StandardOutPath</key>
          <string>#{@home}/Library/Logs/woodblock-wallpaper.out.log</string>
          <key>StandardErrorPath</key>
          <string>#{@home}/Library/Logs/woodblock-wallpaper.err.log</string>
      </dict>
      </plist>
    PLIST
  end
end
