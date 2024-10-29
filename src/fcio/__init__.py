import importlib.metadata
__version__ = importlib.metadata.version("fcio")

from .fcio import FCIO
from .fcio import Tags
from .fcio import Limits

def fcio_open(peer : str, timeout : int = 0, buffersize : int = 0, debug : int = 0, compression : str = 'auto', extended = True) -> FCIO:
  """
  Opens an fcio data file or tcp stream and returns an FCIO object exposing the data fields as well as interaction (reading) from stream.
  All parameters are passed as is to the FCIO constructor, offering some default values.
  """
  return FCIO(peer=peer, timeout=timeout, buffersize=buffersize, debug=debug, compression=compression, extended = extended)
