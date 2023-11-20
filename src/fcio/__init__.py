import importlib.metadata
__version__ = importlib.metadata.version("fcio")

from .cy_fcio import CyFCIO as FCIO
from .cy_fcio import CyFCIOTag as FCIOTag

def fcio_open(filename : str, timeout : int = 0, buffersize : int = 0, debug : int = 0, compression : str = 'auto', extended = False):
  return FCIO(filename=filename, timeout=timeout, buffersize=buffersize, debug=debug, compression=compression, extended = extended)
