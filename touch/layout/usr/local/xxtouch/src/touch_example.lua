require "exlog"
touch = require "touch"
key = require "key"

touch.show_pose(true)

do
  LOG.debug("Wait 5 seconds...")
  touch.msleep(5000)

  LOG.debug("Press HOME")
  key.press_home()
  
  key.msleep(1000)
  LOG.debug("Swipe from right to left")
  touch.on(827,600)
    :step_len(1)
    :step_delay(2)
    :move(0,600)
    :off()
  touch.msleep(1000)
  
  LOG.debug("Swipe from right to left #2")
  touch.on(827,600)
    :step_len(1)
    :step_delay(2)
    :move(0,600)
    :off()
  touch.msleep(1000)
  
  LOG.debug("Swipe from left to right")
  touch.on(0,600)
    :step_len(1)
    :step_delay(2)
    :move(827,600)
    :off()
  touch.msleep(1000)

  LOG.debug("Swipe from left to right #2")
  touch.on(0,600)
    :step_len(1)
    :step_delay(2)
    :move(827,600)
    :off()
  touch.msleep(1000)

  LOG.debug("Lock device")
  key.press_power()
  touch.msleep(1000)

  LOG.debug("Unlock device")
  key.press_home()
  touch.msleep(1000)
  key.press_home()

end
