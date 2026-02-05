-- Test 4369: ON clause - suggest RegionID from Regions table

return {
  number = 4369,
  description = "ON clause - suggest RegionID from Regions table",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Countries c JOIN Regions r ON c.RegionID = r.█",
  expected = {
    items = {
      includes = {
        "RegionID",
      },
    },
    type = "column",
  },
}
