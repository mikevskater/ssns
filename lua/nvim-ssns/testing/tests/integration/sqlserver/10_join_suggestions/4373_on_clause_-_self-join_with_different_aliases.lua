-- Test 4373: ON clause - self-join with different aliases

return {
  number = 4373,
  description = "ON clause - self-join with different aliases",
  database = "vim_dadbod_test",
  query = [[SELECT * FROM Departments d1
JOIN Departments d2 ON d1.ManagerID = d2.█]],
  expected = {
    items = {
      includes = {
        "ManagerID",
        "DepartmentID",
      },
    },
    type = "column",
  },
}
