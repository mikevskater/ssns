-- Test 4712: INSERT - int into varchar column (implicit convert)

return {
  number = 4712,
  description = "INSERT - int into varchar column (implicit convert)",
  database = "vim_dadbod_test",
  query = "INSERT INTO Employees (FirstName) VALUES (12█3)",
  expected = {
    items = {
      includes_any = {
        "implicit_conversion",
      },
    },
    type = "warning",
  },
}
