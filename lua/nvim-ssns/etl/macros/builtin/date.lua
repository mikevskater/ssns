---Built-in date/time helper macros for ETL scripts
---@module ssns.etl.macros.builtin.date

return {
  ---Get current date/time formatted
  ---@param format string? strftime format (default: "%Y-%m-%d %H:%M:%S")
  ---@return string datetime
  now = function(format)
    format = format or "%Y-%m-%d %H:%M:%S"
    return os.date(format)
  end,

  ---Get current date (no time)
  ---@param format string? strftime format (default: "%Y-%m-%d")
  ---@return string date
  today = function(format)
    format = format or "%Y-%m-%d"
    return os.date(format)
  end,

  ---Get date N days ago
  ---@param days number Number of days ago
  ---@param format string? strftime format (default: "%Y-%m-%d")
  ---@return string date
  days_ago = function(days, format)
    format = format or "%Y-%m-%d"
    local time = os.time() - (days * 24 * 60 * 60)
    return os.date(format, time)
  end,

  ---Get date N days from now
  ---@param days number Number of days from now
  ---@param format string? strftime format (default: "%Y-%m-%d")
  ---@return string date
  days_from_now = function(days, format)
    format = format or "%Y-%m-%d"
    local time = os.time() + (days * 24 * 60 * 60)
    return os.date(format, time)
  end,

  ---Get start of current month
  ---@param format string? strftime format (default: "%Y-%m-%d")
  ---@return string date
  start_of_month = function(format)
    format = format or "%Y-%m-%d"
    local now = os.date("*t")
    now.day = 1
    return os.date(format, os.time(now))
  end,

  ---Get end of current month
  ---@param format string? strftime format (default: "%Y-%m-%d")
  ---@return string date
  end_of_month = function(format)
    format = format or "%Y-%m-%d"
    local now = os.date("*t")
    -- Go to first of next month, then back one day
    now.month = now.month + 1
    now.day = 0
    return os.date(format, os.time(now))
  end,

  ---Get start of current year
  ---@param format string? strftime format (default: "%Y-%m-%d")
  ---@return string date
  start_of_year = function(format)
    format = format or "%Y-%m-%d"
    local now = os.date("*t")
    now.month = 1
    now.day = 1
    return os.date(format, os.time(now))
  end,

  ---Get end of current year
  ---@param format string? strftime format (default: "%Y-%m-%d")
  ---@return string date
  end_of_year = function(format)
    format = format or "%Y-%m-%d"
    local now = os.date("*t")
    now.month = 12
    now.day = 31
    return os.date(format, os.time(now))
  end,

  ---Get start of current week (Monday)
  ---@param format string? strftime format (default: "%Y-%m-%d")
  ---@return string date
  start_of_week = function(format)
    format = format or "%Y-%m-%d"
    local now = os.date("*t")
    -- wday: Sunday=1, Monday=2, etc.
    local days_since_monday = (now.wday + 5) % 7
    local time = os.time() - (days_since_monday * 24 * 60 * 60)
    return os.date(format, time)
  end,

  ---Get start of previous month
  ---@param format string? strftime format (default: "%Y-%m-%d")
  ---@return string date
  start_of_prev_month = function(format)
    format = format or "%Y-%m-%d"
    local now = os.date("*t")
    now.month = now.month - 1
    now.day = 1
    return os.date(format, os.time(now))
  end,

  ---Get end of previous month
  ---@param format string? strftime format (default: "%Y-%m-%d")
  ---@return string date
  end_of_prev_month = function(format)
    format = format or "%Y-%m-%d"
    local now = os.date("*t")
    now.day = 0 -- Goes to last day of previous month
    return os.date(format, os.time(now))
  end,

  ---Format a date string from one format to another
  ---@param date_str string Date string to format
  ---@param from_format string? Input format pattern (default: "%Y-%m-%d")
  ---@param to_format string? Output format pattern (default: "%Y-%m-%d")
  ---@return string? formatted Formatted date or nil if parse failed
  format_date = function(date_str, from_format, to_format)
    from_format = from_format or "%Y-%m-%d"
    to_format = to_format or "%Y-%m-%d"

    -- Parse the input date
    -- Note: Lua's os.date/os.time doesn't have strptime, so we use pattern matching
    -- This handles common formats

    -- Try YYYY-MM-DD
    local year, month, day = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if not year then
      -- Try MM/DD/YYYY
      month, day, year = date_str:match("^(%d%d?)/(%d%d?)/(%d%d%d%d)")
    end
    if not year then
      -- Try DD/MM/YYYY
      day, month, year = date_str:match("^(%d%d?)/(%d%d?)/(%d%d%d%d)")
    end

    if not year then
      return nil
    end

    local time = os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
    })

    return os.date(to_format, time)
  end,

  ---Parse a date string to components
  ---@param date_str string Date string (YYYY-MM-DD format)
  ---@return table? components {year, month, day} or nil
  parse_date = function(date_str)
    local year, month, day = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if year then
      return {
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
      }
    end
    return nil
  end,

  ---Add months to a date
  ---@param date_str string Date in YYYY-MM-DD format
  ---@param months number Months to add (negative to subtract)
  ---@param format string? Output format (default: "%Y-%m-%d")
  ---@return string date
  add_months = function(date_str, months, format)
    format = format or "%Y-%m-%d"
    local year, month, day = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    if not year then
      return date_str -- Return original if parse fails
    end

    local dt = {
      year = tonumber(year),
      month = tonumber(month) + months,
      day = tonumber(day),
    }

    return os.date(format, os.time(dt))
  end,

  ---Get the quarter for a date
  ---@param date_str string? Date in YYYY-MM-DD format (nil for today)
  ---@return number quarter 1-4
  get_quarter = function(date_str)
    local month
    if date_str then
      month = tonumber(date_str:match("^%d%d%d%d%-(%d%d)"))
    else
      month = tonumber(os.date("%m"))
    end
    return math.ceil(month / 3)
  end,

  ---Get fiscal year (assuming fiscal year starts in a given month)
  ---@param date_str string? Date in YYYY-MM-DD format (nil for today)
  ---@param fiscal_start_month number? Month fiscal year starts (default: 7 for July)
  ---@return number fiscal_year
  get_fiscal_year = function(date_str, fiscal_start_month)
    fiscal_start_month = fiscal_start_month or 7
    local year, month
    if date_str then
      year = tonumber(date_str:match("^(%d%d%d%d)"))
      month = tonumber(date_str:match("^%d%d%d%d%-(%d%d)"))
    else
      local now = os.date("*t")
      year = now.year
      month = now.month
    end

    if month >= fiscal_start_month then
      return year + 1
    else
      return year
    end
  end,

  ---Check if a date is a weekend
  ---@param date_str string? Date in YYYY-MM-DD format (nil for today)
  ---@return boolean is_weekend
  is_weekend = function(date_str)
    local wday
    if date_str then
      local year, month, day = date_str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
      if year then
        local time = os.time({
          year = tonumber(year),
          month = tonumber(month),
          day = tonumber(day),
        })
        wday = tonumber(os.date("%w", time))
      end
    else
      wday = tonumber(os.date("%w"))
    end
    -- 0 = Sunday, 6 = Saturday
    return wday == 0 or wday == 6
  end,

  ---Calculate difference between two dates in days
  ---@param date1 string First date (YYYY-MM-DD)
  ---@param date2 string Second date (YYYY-MM-DD)
  ---@return number? days Difference in days (positive if date1 > date2)
  date_diff = function(date1, date2)
    local y1, m1, d1 = date1:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    local y2, m2, d2 = date2:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")

    if not y1 or not y2 then
      return nil
    end

    local time1 = os.time({ year = tonumber(y1), month = tonumber(m1), day = tonumber(d1) })
    local time2 = os.time({ year = tonumber(y2), month = tonumber(m2), day = tonumber(d2) })

    return math.floor((time1 - time2) / (24 * 60 * 60))
  end,

  ---Generate a date range as a table
  ---@param start_date string Start date (YYYY-MM-DD)
  ---@param end_date string End date (YYYY-MM-DD)
  ---@param format string? Output format (default: "%Y-%m-%d")
  ---@return string[] dates Array of formatted dates
  date_range = function(start_date, end_date, format)
    format = format or "%Y-%m-%d"
    local dates = {}

    local y1, m1, d1 = start_date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")
    local y2, m2, d2 = end_date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)")

    if not y1 or not y2 then
      return dates
    end

    local time1 = os.time({ year = tonumber(y1), month = tonumber(m1), day = tonumber(d1) })
    local time2 = os.time({ year = tonumber(y2), month = tonumber(m2), day = tonumber(d2) })

    local current = time1
    while current <= time2 do
      table.insert(dates, os.date(format, current))
      current = current + (24 * 60 * 60) -- Add one day
    end

    return dates
  end,

  ---Get timestamp (Unix epoch)
  ---@return number timestamp
  timestamp = function()
    return os.time()
  end,

  ---Convert timestamp to date string
  ---@param timestamp number Unix timestamp
  ---@param format string? strftime format (default: "%Y-%m-%d %H:%M:%S")
  ---@return string datetime
  from_timestamp = function(timestamp, format)
    format = format or "%Y-%m-%d %H:%M:%S"
    return os.date(format, timestamp)
  end,
}
