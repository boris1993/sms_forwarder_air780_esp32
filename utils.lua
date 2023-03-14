local utils = {}

function utils.bool_to_number(value)
    return value and 1 or 0
end

function utils.is_empty(str)
    return str == nil or str == ""
end

function utils.clear_table(table)
    for i = 0, #table do
        table[i] = nil
    end
end

return utils