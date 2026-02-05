-- Test 4489: Temp table - mixed local and global
-- SKIPPED: Temp table completion not yet supported

return {
  number = 4489,
  description = "Temp table - mixed local and global",
  database = "vim_dadbod_test",
  skip = false,
  query = [[CREATE TABLE #LocalTemp (ID INT)
CREATE TABLE ##GlobalTemp (GID INT)
SELECT * FROM █]],
  expected = {
    items = {
      includes = {
        "#LocalTemp",
        "##GlobalTemp",
      },
    },
    type = "table",
  },
}
