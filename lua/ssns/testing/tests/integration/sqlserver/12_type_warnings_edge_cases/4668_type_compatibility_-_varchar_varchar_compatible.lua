-- Test 4668: Type compatibility - varchar = varchar (compatible)

return {
  number = 4668,
  description = "Type compatibility - varchar = varchar (compatible)",
  database = "vim_dadbod_test",
  query = "SELECT * FROM Customers WHERE Name = Email█",
  expected = {
    items = {
      valid = true,
    },
    type = "no_warning",
  },
}
