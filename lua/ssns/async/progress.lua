---Progress tracking for bulk/batched async operations
---@class ProgressModule
local Progress = {}

---@class ProgressTracker
---@field total number Total items to process
---@field current number Current item index (0-based initially)
---@field start_time number Start timestamp (vim.loop.hrtime)
---@field items_per_second number? Calculated throughput
---@field estimated_remaining_ms number? Estimated time remaining
---@field on_update fun(pct: number, tracker: ProgressTracker)? Progress callback
---@field message string? Current progress message
local ProgressTracker = {}
ProgressTracker.__index = ProgressTracker

---@class ProgressOpts
---@field on_update fun(pct: number, tracker: ProgressTracker)? Called on progress changes
---@field message string? Initial message

---Create a new progress tracker
---@param total number Total number of items to process
---@param opts ProgressOpts? Options
---@return ProgressTracker
function Progress.create(total, opts)
  opts = opts or {}

  local tracker = setmetatable({
    total = math.max(1, total), -- Avoid division by zero
    current = 0,
    start_time = vim.loop.hrtime(),
    items_per_second = nil,
    estimated_remaining_ms = nil,
    on_update = opts.on_update,
    message = opts.message,
  }, ProgressTracker)

  return tracker
end

---Advance progress by a given amount
---@param amount number? Amount to advance (default: 1)
function ProgressTracker:advance(amount)
  amount = amount or 1
  self.current = math.min(self.current + amount, self.total)

  -- Calculate metrics
  local elapsed_ms = (vim.loop.hrtime() - self.start_time) / 1e6

  if elapsed_ms > 0 and self.current > 0 then
    self.items_per_second = self.current / (elapsed_ms / 1000)

    local remaining_items = self.total - self.current
    if self.items_per_second > 0 then
      self.estimated_remaining_ms = (remaining_items / self.items_per_second) * 1000
    end
  end

  -- Invoke callback
  if self.on_update then
    local pct = self:get_percentage()
    self.on_update(pct, self)
  end
end

---Set progress to a specific value
---@param value number Current progress value
function ProgressTracker:set(value)
  local old_current = self.current
  self.current = math.max(0, math.min(value, self.total))

  if self.current ~= old_current then
    -- Recalculate metrics
    local elapsed_ms = (vim.loop.hrtime() - self.start_time) / 1e6

    if elapsed_ms > 0 and self.current > 0 then
      self.items_per_second = self.current / (elapsed_ms / 1000)

      local remaining_items = self.total - self.current
      if self.items_per_second > 0 then
        self.estimated_remaining_ms = (remaining_items / self.items_per_second) * 1000
      end
    end

    -- Invoke callback
    if self.on_update then
      local pct = self:get_percentage()
      self.on_update(pct, self)
    end
  end
end

---Set progress message
---@param message string Progress message
function ProgressTracker:set_message(message)
  self.message = message
  -- Invoke callback with current percentage
  if self.on_update then
    self.on_update(self:get_percentage(), self)
  end
end

---Get current percentage (0-100)
---@return number percentage
function ProgressTracker:get_percentage()
  return (self.current / self.total) * 100
end

---Get elapsed time in milliseconds
---@return number elapsed_ms
function ProgressTracker:get_elapsed_ms()
  return (vim.loop.hrtime() - self.start_time) / 1e6
end

---Check if progress is complete
---@return boolean is_complete
function ProgressTracker:is_complete()
  return self.current >= self.total
end

---Format progress as string (e.g., "50/100 (50%)")
---@return string formatted
function ProgressTracker:format()
  local pct = self:get_percentage()
  return string.format("%d/%d (%.0f%%)", self.current, self.total, pct)
end

---Format progress with message
---@return string formatted
function ProgressTracker:format_with_message()
  local base = self:format()
  if self.message then
    return self.message .. " " .. base
  end
  return base
end

---Format estimated time remaining
---@return string? formatted Formatted ETA or nil if not calculable
function ProgressTracker:format_eta()
  if not self.estimated_remaining_ms or self.estimated_remaining_ms <= 0 then
    return nil
  end

  local remaining_seconds = math.ceil(self.estimated_remaining_ms / 1000)

  if remaining_seconds < 60 then
    return string.format("%ds remaining", remaining_seconds)
  elseif remaining_seconds < 3600 then
    local minutes = math.floor(remaining_seconds / 60)
    local seconds = remaining_seconds % 60
    return string.format("%dm %ds remaining", minutes, seconds)
  else
    local hours = math.floor(remaining_seconds / 3600)
    local minutes = math.floor((remaining_seconds % 3600) / 60)
    return string.format("%dh %dm remaining", hours, minutes)
  end
end

---Create a sub-tracker that reports to a parent tracker
---Useful for nested progress (e.g., processing files within directories)
---@param parent ProgressTracker Parent tracker
---@param weight number Weight of this sub-task in parent (0-1 or absolute)
---@param total number Total items in sub-task
---@return ProgressTracker sub_tracker
function Progress.create_sub_tracker(parent, weight, total)
  local parent_start = parent.current
  local parent_range = weight

  local sub = Progress.create(total, {
    on_update = function(pct, _)
      -- Map sub-progress to parent range
      local parent_progress = parent_start + (pct / 100) * parent_range
      parent:set(parent_progress)
    end,
  })

  return sub
end

---Run a batch operation with progress tracking
---@generic T
---@param items T[] Items to process
---@param processor fun(item: T, index: number, tracker: ProgressTracker): any? Processing function
---@param opts { on_progress: fun(pct: number, tracker: ProgressTracker)?, message: string? }? Options
---@return any[] results Results from processor
function Progress.batch(items, processor, opts)
  opts = opts or {}

  local tracker = Progress.create(#items, {
    on_update = opts.on_progress,
    message = opts.message,
  })

  local results = {}

  for i, item in ipairs(items) do
    local result = processor(item, i, tracker)
    table.insert(results, result)
    tracker:advance()
  end

  return results
end

return Progress
