on adding folder items to this_folder after receiving added_items
  set inbox_path to POSIX path of ((path to home folder as text) & "Documents:Inbox:")

  repeat with added_item in added_items
    my move_item_if_ready(added_item as alias, inbox_path)
  end repeat
end adding folder items to

on move_item_if_ready(item_alias, inbox_path)
  try
    set item_info to info for item_alias
    if folder of item_info then return

    set item_name to name of item_info
    if my should_skip_name(item_name) then return
    if not my file_size_stable(item_alias) then return

    set item_path to POSIX path of item_alias
    set destination_path to my unique_destination_path(inbox_path, item_name)

    do shell script "/bin/mkdir -p " & quoted form of inbox_path
    do shell script "/bin/mv " & quoted form of item_path & " " & quoted form of destination_path
  end try
end move_item_if_ready

on should_skip_name(item_name)
  repeat with suffix in {".crdownload", ".download", ".part", ".tmp"}
    if item_name ends with (suffix as text) then return true
  end repeat

  return false
end should_skip_name

on file_size_stable(item_alias)
  repeat 5 times
    try
      set first_size to size of (info for item_alias)
      delay 2
      set second_size to size of (info for item_alias)
      if first_size is second_size then return true
    on error
      return false
    end try
  end repeat

  return false
end file_size_stable

on unique_destination_path(folder_path, item_name)
  set {base_name, extension_suffix} to my split_name(item_name)
  set candidate_path to folder_path & item_name
  set counter to 1

  repeat while my path_exists(candidate_path)
    set counter to counter + 1
    set candidate_path to folder_path & base_name & " " & counter & extension_suffix
  end repeat

  return candidate_path
end unique_destination_path

on path_exists(posix_path)
  try
    do shell script "/usr/bin/test -e " & quoted form of posix_path
    return true
  on error
    return false
  end try
end path_exists

on split_name(item_name)
  set old_delimiters to AppleScript's text item delimiters
  set result_name_parts to {item_name, ""}

  try
    if item_name does not contain "." then return result_name_parts

    set AppleScript's text item delimiters to "."
    set parts to text items of item_name
    if (count of parts) is 1 then return result_name_parts

    set extension_suffix to "." & (last item of parts)
    set base_name to ((items 1 thru -2 of parts) as text)
    if base_name is not "" then set result_name_parts to {base_name, extension_suffix}
  end try

  set AppleScript's text item delimiters to old_delimiters
  return result_name_parts
end split_name
