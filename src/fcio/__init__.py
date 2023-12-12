import importlib.metadata
__version__ = importlib.metadata.version("fcio")

from .cy_fcio import CyFCIO as FCIO
from .cy_fcio import CyFCIOTag as FCIOTag
from .cy_fcio import CyFCIOLimit as FCIOLimit

def fcio_open(filename : str, timeout : int = 0, buffersize : int = 0, debug : int = 0, compression : str = 'auto', extended = True) -> FCIO:
  """
  Opens an fcio data file or tcp stream and returns an FCIO object exposing the data fields as well as interaction (reading) from stream.
  All parameters are passed as is to the FCIO constructor, offering some default values.
  """
  return FCIO(filename=filename, timeout=timeout, buffersize=buffersize, debug=debug, compression=compression, extended = extended)
