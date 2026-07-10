local Marg = {}

local function is_help_flag(arg)
    return arg == '--help' or arg == '-h'
end

local function show_top_help(param)
    if param.usage then
        print(param.usage)
    end
    if param.help then
        for section, content in pairs(param.help) do
            if section == 'Commands' then
                print('--> Commands')
                for i = 1, #content do
                    local entry = content[i]
                    if type(entry) == 'string' then
                        print(('  %-10s %s'):format(entry, content.msg or ''))
                    end
                end
            else
                print(('--> %s'):format(section))
                print(content)
            end
        end
    end
end

local function show_cmd_help(cmd_param)
    local help = cmd_param.help or {}
    local template = help.template or '\n%s:'
    local sections = {}

    if cmd_param.space then
        for _, spec in ipairs(cmd_param.space) do
            local flag_str = table.concat(spec.flag, ',')
            local h = spec.help
            if type(h) == 'string' then
                print(('  %-14s %s'):format(flag_str, h))
            elseif type(h) == 'table' then
                for sec, text in pairs(h) do
                    sections[sec] = sections[sec] or {}
                    table.insert(sections[sec], { flags = flag_str, text = text })
                end
            end
        end
    end

    if cmd_param.single then
        for _, spec in ipairs(cmd_param.single) do
            if type(spec) == 'table' then
                local flag = spec[1]
                local h = spec.help
                if type(h) == 'string' then
                    print(('  %-14s %s'):format(flag, h))
                elseif type(h) == 'table' then
                    for sec, text in pairs(h) do
                        sections[sec] = sections[sec] or {}
                        table.insert(sections[sec], { flags = flag, text = text })
                    end
                end
            end
        end
    end

    if cmd_param.equal then
        local function add_equal_help(eq)
            if type(eq) == 'string' then
                print(('  %-14s %s'):format(eq .. '=VALUE', ''))
            elseif type(eq) == 'table' then
                local flag = eq[1]
                local h = eq.help
                if type(h) == 'string' then
                    print(('  %-14s %s'):format(flag .. '=VALUE', h))
                end
            end
        end
        if type(cmd_param.equal[1]) == 'string' then
            add_equal_help(cmd_param.equal)
        elseif type(cmd_param.equal[1]) == 'table' then
            for _, eq in ipairs(cmd_param.equal) do
                add_equal_help(eq)
            end
        end
    end

    print()

    for section, content in pairs(help) do
        if section ~= 'flag' and section ~= 'template' then
            print(template:format(section))
            print(content)
        end
    end

    for section, entries in pairs(sections) do
        print(template:format(section))
        for _, entry in ipairs(entries) do
            print(('  %-14s %s'):format(entry.flags, entry.text))
        end
    end
end

local function build_equal_keys(equal_spec)
    local keys = {}
    if type(equal_spec[1]) == 'string' then
        for _, v in ipairs(equal_spec) do
            keys[v] = true
        end
    elseif type(equal_spec[1]) == 'table' then
        for _, entry in ipairs(equal_spec) do
            keys[entry[1]] = true
        end
    end
    return keys
end

local function build_space_map(space_spec)
    local map = {}
    for _, spec in ipairs(space_spec) do
        for _, f in ipairs(spec.flag) do
            map[f] = spec
        end
    end
    return map
end

local function build_single_maps(single_spec)
    local by_flag = {}
    local by_pattern = {}
    for _, spec in ipairs(single_spec) do
        local flag = type(spec) == 'string' and spec or spec[1]
        if type(spec) == 'table' and spec.pattern then
            by_pattern[flag] = spec
        else
            by_flag[flag] = type(spec) == 'string' and { [1] = spec } or spec
        end
    end
    return by_flag, by_pattern
end

local function is_option_like(arg, space_map, equal_keys, single_by_flag, single_by_pattern)
    if space_map[arg] then
        return true
    end
    if single_by_flag[arg] then
        return true
    end
    if arg:find('=', 1, true) then
        local key = arg:match('^(.-)=')
        if key and equal_keys[key] then
            return true
        end
    end
    for _, spec in pairs(single_by_pattern) do
        if arg:match(spec.pattern) then
            return true
        end
    end
    return false
end

function Marg.parse(args, param)
    local result = {}

    if #args == 0 then
        return result
    end

    if is_help_flag(args[1]) then
        show_top_help(param)
        os.exit(0)
    end

    if param.single then
        local specs
        if type(param.single[1]) == 'string' then
            specs = { param.single }
        else
            specs = param.single
        end
        for _, spec in ipairs(specs) do
            local flag = type(spec) == 'string' and spec or spec[1]
            if args[1] == flag then
                result[flag] = true
                if spec.only then
                    return result
                end
            end
        end
    end

    local cmd = args[1]
    local cmd_param = param[cmd]
    if not cmd_param then
        return result
    end

    local cmd_result = {}
    result[cmd] = cmd_result

    local help_flags = cmd_param.help and cmd_param.help.flag or {}
    local help_set = {}
    for _, f in ipairs(help_flags) do
        help_set[f] = true
    end

    local equal_keys = {}
    if cmd_param.equal then
        equal_keys = build_equal_keys(cmd_param.equal)
    end

    local space_map = {}
    if cmd_param.space then
        space_map = build_space_map(cmd_param.space)
    end

    local single_by_flag, single_by_pattern = {}, {}
    if cmd_param.single then
        single_by_flag, single_by_pattern = build_single_maps(cmd_param.single)
    end

    local i = 2
    while i <= #args do
        local arg = args[i]

        if help_set[arg] then
            show_cmd_help(cmd_param)
            os.exit(0)
        end

        local space_spec = space_map[arg]
        if space_spec then
            i = i + 1
            if space_spec.multi then
                if not cmd_result[space_spec.tag] then
                    cmd_result[space_spec.tag] = {}
                end
                while i <= #args do
                    local v = args[i]
                    if is_option_like(v, space_map, equal_keys, single_by_flag, single_by_pattern) then
                        break
                    end
                    table.insert(cmd_result[space_spec.tag], v)
                    i = i + 1
                end
            else
                if i <= #args then
                    cmd_result[space_spec.tag] = args[i]
                    i = i + 1
                end
            end
            goto continue
        end

        local eq_pos = arg:find('=', 1, true)
        if eq_pos then
            local key = arg:sub(1, eq_pos - 1)
            local val = arg:sub(eq_pos + 1)
            if equal_keys[key] then
                cmd_result[key] = val
                i = i + 1
                goto continue
            end
        end

        local single_spec = single_by_flag[arg]
        if single_spec then
            local tag = single_spec.tag or single_spec[1]
            cmd_result[tag] = true
            if single_spec.only then
                return result
            end
            i = i + 1
            goto continue
        end

        for _, spec in pairs(single_by_pattern) do
            local captures = { arg:match(spec.pattern) }
            if #captures > 0 then
                cmd_result[spec.tag] = captures[1]
                if spec.only then
                    return result
                end
                i = i + 1
                goto continue
            end
        end

        i = i + 1
        ::continue::
    end

    return result
end

return Marg
