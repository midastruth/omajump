-- OmaJump's lone-Super launcher.
-- XKB keycodes 133 and 134 are Super_L and Super_R. Raw key events let us
-- cancel the tap whenever another key is pressed, preserving every Super chord.
do
  local super_keys = { [133] = true, [134] = true }
  local held = {}
  local lone_tap = {}

  hl.on("input.keyboard.key", function(keycode, _, state)
    if super_keys[keycode] then
      if state == 1 then
        local another_super_is_held = false
        for code in pairs(held) do
          if code ~= keycode then another_super_is_held = true end
        end

        if another_super_is_held then
          for code in pairs(lone_tap) do lone_tap[code] = false end
          lone_tap[keycode] = false
        else
          lone_tap[keycode] = true
        end
        held[keycode] = true
      elseif state == 0 then
        local should_open = held[keycode] and lone_tap[keycode]
        held[keycode] = nil
        lone_tap[keycode] = nil
        if should_open and hl.get_current_submap() == "" then
          hl.exec_cmd("omarchy-shell shell summon io.github.midastruth.omajump '{}'")
        end
      end
      return
    end

    if state == 1 then
      for code in pairs(held) do lone_tap[code] = false end
    end
  end)
end
