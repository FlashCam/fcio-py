import numpy as np

class CardStatus:
  def __init__(self, raw_card_status_struct):
    self.buffer = raw_card_status_struct

  @property
  def reqid(self):
    return self.buffer.reqid

  @property
  def status(self):
    return self.buffer.status

  @property
  def eventno(self):
    return self.buffer.eventno

  @property
  def pps(self):
    return self.buffer.pps

  @property
  def ticks(self):
    return self.buffer.ticks

  @property
  def maxticks(self):
    return self.buffer.maxticks

  @property
  def numenv(self):
    return self.buffer.numenv

  @property
  def numctilinks(self):
    return self.buffer.numctilinks

  @property
  def numlinks(self):
    return self.buffer.numlinks

  @property
  def dummy(self):
    return self.buffer.dummy

  @property
  def totalerrors(self):
    return self.buffer.totalerrors

  @property
  def othererrors(self):
    return np.ndarray(shape=(5), dtype=np.uint16, offset=0, buffer=self.buffer.othererrors)

  @property
  def environment(self):
    return np.ndarray(shape=(self.numenv), dtype=np.uint16, offset=0, buffer=self.buffer.environment)

  @property
  def ctierrors(self):
    return np.ndarray(shape=(self.numctilinks), dtype=np.uint16, offset=0, buffer=self.buffer.ctierrors)

  @property
  def linkerrors(self):
    return np.ndarray(shape=(self.numlinks), dtype=np.uint16, offset=0, buffer=self.buffer.linkerrors)

  @property
  def enverrors(self):
    return np.ndarray(shape=(self.numlinks), dtype=np.uint16, offset=0, buffer=self.buffer.enverrors)


class Status:
  def __init__(self, raw_status_struct, config):
    self.buffer = raw_status_struct
    self.config = config

  @property
  def status(self):
    return self.buffer.status

  @property
  def statustime(self):
    return self.buffer.statustime
  
  @property
  def statustime_master_sec(self):
    return np.float64(self.buffer.statustime[0]) + np.float64(self.buffer.statustime[1]) * 1e-6
  
  @property
  def statustime_server_sec(self):
    return np.float64(self.buffer.statustime[2]) + np.float64(self.buffer.statustime[3]) * 1e-6
  
  @property
  def starttime_master_sec(self):
    return np.float64(self.buffer.statustime[5]) + np.float64(self.buffer.statustime[6]) * 1e-6

  @property
  def cards(self):
    return self.buffer.cards

  @property
  def size(self):
    return self.buffer.size

  @property
  def card_status(self):
    for i in range(self.cards):
      yield CardStatus(self.buffer.data[i])
      
  @property
  def master_card_status(self):
    for i in range(0,self.config.mastercards):
      yield CardStatus(self.buffer.data[i])
  
  @property
  def trigger_card_status(self):
    for i in range(self.config.mastercards, self.config.mastercards + self.config.triggercards):
      yield CardStatus(self.buffer.data[i])

  @property
  def adc_card_status(self):
    for i in range(self.config.mastercards + self.config.triggercards, self.cards):
      yield CardStatus(self.buffer.data[i])
