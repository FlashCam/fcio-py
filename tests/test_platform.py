
def test_system_precision():
  """
    Not expected to be relevant. It's here to test
    incase the eventtime and other attributes in FCIOEvent will ever
    support float128 reliably, to fit the 19 decimal unix timestamp
    with nanoseconds precision.

    We expect the int64 to always return correctly here, so
    the unixtimestamp with 19 decimals fits into int64.
  """
  import numpy as np

  assert str(np.iinfo(np.int64).max) == "9223372036854775807"
  assert str(np.iinfo(np.int64).min) == "-9223372036854775808"
