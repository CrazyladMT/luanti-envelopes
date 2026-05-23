local f = string.format
local esc = core.formspec_escape
local has_canonical_name = core.get_modpath("canonical_name")

local function normalize_name(name)
    if has_canonical_name then
        return canonical_name.get(name) or name
    end
    return name
end

local function make_sealed(sender, receiver, text, attn)
    local item = ItemStack("envelopes:envelope_sealed")
    local meta = item:get_meta()

    local desc = ("Sealed Envelope\nTo: %s\nFrom: %s"):format(receiver, sender)
    if attn ~= "" then
        desc = desc .. "\nAttn: " .. attn
    end

    meta:set_string("sender", sender)
    meta:set_string("receiver", receiver)
    meta:set_string("text", text)
    meta:set_string("attn", attn)
    meta:set_string("description", desc)

    return item
end

local function open_envelope(stack)
    local meta = stack:get_meta()
    local sender = meta:get_string("sender")
    local receiver = meta:get_string("receiver")
    local text = meta:get_string("text")
    local attn = meta:get_string("attn")

    local opened = ItemStack("envelopes:envelope_opened")
    local om = opened:get_meta()

    local desc = ("Opened Envelope\nTo: %s\nFrom: %s"):format(receiver, sender)
    if attn ~= "" then
        desc = desc .. "\nAttn: " .. attn
    end

    om:set_string("sender", sender)
    om:set_string("receiver", receiver)
    om:set_string("text", text)
    om:set_string("attn", attn)
    om:set_string("description", desc)

    return opened
end

core.register_craftitem("envelopes:envelope_blank", {
    description = "Blank Envelope",
    inventory_image = "envelopes_envelope_blank.png",
    on_use = function(stack, user, pointed_thing)
        core.show_formspec(user:get_player_name(), "envelopes:input",
            "size[5.5,5.5]" ..
            "field[2,0.5;3.5,1;addressee;Addressee;]" ..
            "label[0,0;Write a letter]" ..
            "textarea[0.5,1.5;5,3;text;Text;]" ..
            "field[3,4.8;2.5,1;attn;Attn. (Optional);]" ..
            "button_exit[0.25,4.5;2,1;exit;Seal]")
        return stack
    end
})

core.register_craftitem("envelopes:envelope_sealed", {
    description = "Sealed Envelope",
    inventory_image = "envelopes_envelope_sealed.png",
    stack_max = 1,
    groups = {not_in_creative_inventory = 1},
    on_use = function(stack, user, pointed_thing)
        local meta = stack:get_meta()
        local receiver = normalize_name(meta:get_string("receiver"))
        local user_name = user:get_player_name()

        if user_name ~= receiver then
            core.chat_send_player(user_name, f("The seal can only be opened by %s!", receiver))
            return stack
        end

        return open_envelope(stack)
    end
})

core.register_craftitem("envelopes:envelope_opened", {
    description = "Opened Envelope",
    inventory_image = "envelopes_envelope_opened.png",
    stack_max = 1,
    groups = {not_in_creative_inventory = 1},
    on_use = function(stack, user, pointed_thing)
        local meta = stack:get_meta()
        local sender = esc(meta:get_string("sender"))
        local receiver = esc(meta:get_string("receiver"))
        local text = esc(meta:get_string("text"))
        local attn = esc(meta:get_string("attn"))

        local formatted_attn = attn ~= "" and ("\n<style color=yellow>Attn:</style>    " .. attn .. "</b>") or ""

        local W = 9
        local H = 8

        local pad = 0.375
        local image_size = 0.75
        local exit_btn_size = 0.62

        local fs = {
            "formspec_version[7]",
            f("size[%d,%d]", W, H),

            -- envelope icon
			f("image[%g,%g;%g,%g;%s]", pad, pad, image_size, image_size,
					esc("envelopes_envelope_opened.png")),

			-- header
			f("hypertext[%g,%g;%g,%g;envelope_header_hypertext;%s]",
					pad * 2 + image_size, pad,
					W - (pad * 4 + image_size) - exit_btn_size, pad * 2 + image_size,
					"<b><style color=yellow>From:</style>   " .. sender
					.. "\n<style color=yellow>To:</style>        " .. receiver
					.. formatted_attn),

			-- exit button (top-right)
			f("image_button_exit[%g,%g;%g,%g;%s;envelopes_display_exit;]", W - pad - exit_btn_size,
					pad, exit_btn_size, exit_btn_size, esc("envelopes_clear.png")),

			f("textarea[%g,%g;%g,%g;;;%s]",
					pad, pad * 3 + image_size, W - (pad * 2),
					H - (pad * 3 + image_size) - pad, text)
		}

        core.show_formspec(user:get_player_name(), "envelope:display", table.concat(fs, ""))
    end
})

core.register_on_player_receive_fields(function(player, formname, fields)
    if formname ~= "envelopes:input" then
        return false
    end

    local sender_name = player:get_player_name()

    local addressee = normalize_name((fields.addressee or ""):trim())
    local text = (fields.text or ""):trim()
    local attn = (fields.attn or ""):trim()

    if addressee == "" or text == "" then
        core.chat_send_player(sender_name, "Please fill out all required fields.")
        return true
    end

    if not core.player_exists(addressee) then
        core.chat_send_player(sender_name, f("unknown addressee %q", addressee))
        return true
    end

    local inv = player:get_inventory()
    local letter = make_sealed(sender_name, addressee, text, attn)
    local blank = ItemStack("envelopes:envelope_blank")

    if inv:room_for_item("main", letter) and inv:contains_item("main", blank) then
        inv:add_item("main", letter)
        inv:remove_item("main", blank)
    else
        core.chat_send_player(sender_name, "Unable to create letter! Check your inventory space.")
    end

    return true
end)

if core.get_modpath("default") then
    core.register_craft({
        type = "shaped",
        output = "envelopes:envelope_blank 1",
        recipe = {
            {"", "", ""},
            {"default:paper", "default:paper", "default:paper"},
            {"default:paper", "default:paper", "default:paper"}
        }
    })
end
