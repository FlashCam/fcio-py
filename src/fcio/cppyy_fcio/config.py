import numpy as np

class Config:
  def __init__(self, raw_event_struct):
    self.buffer = raw_event_struct
    
    self._tracemap = np.ndarray(buffer=self.buffer.tracemap,
                                dtype=np.uint32,
                                shape=(self.nadcs, ))
    self._tracemap.setflags(write=False)
    
    self._card_addresses = np.ndarray(buffer=self.buffer.tracemap,
                                dtype=np.uint16,
                                shape=(self.nadcs, ),
                                offset=0,
                                strides=(4,)
                                )
    self._card_addresses.setflags(write=False)
    
    self._card_channel = np.ndarray(buffer=self.buffer.tracemap,
                                dtype=np.uint16,
                                shape=(self.nadcs, ),
                                offset=2,
                                strides=(4,)
                                )
    self._card_channel.setflags(write=False)

  @property
  def nsamples(self):
    return self.buffer.eventsamples

  @property
  def nadcs(self):
    return self.buffer.adcs

  @property
  def telid(self):
    return self.buffer.telid

  @property
  def ntriggers(self):
    return self.buffer.triggers

  @property
  def adcbits(self):
    return self.buffer.adcbits

  @property
  def sumlength(self):
    return self.buffer.sumlength

  @property
  def blprecision(self):
    return self.buffer.blprecision

  @property
  def mastercards(self):
    return self.buffer.mastercards

  @property
  def triggercards(self):
    return self.buffer.triggercards

  @property
  def adccards(self):
    return self.buffer.adccards

  @property
  def gps(self):
    return self.buffer.gps
  
  @property
  def tracemap(self):
    return self._tracemap
  
  @property
  def card_addresses(self):
    return self._addresses
  
  @property
  def card_channel(self):
    return self._card_channel