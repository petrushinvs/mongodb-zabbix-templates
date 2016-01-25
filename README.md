# mongodb-zabbix-templates
Zabbix templates for mongodb monitoring

For a long time I've used the Mikoomi mongodb template for mongodb monitoring. It was work fine for us for all mongodb 2.x versions. 
Since mongodb 3.x it fails and after a few patches I decide to made my own simple templates.
The main tasks of monitoring for us:

#  Watch and notify the support team if mongodb instances is not running or not reachable
# Watch a basic mongodb and mongos opcounters
# Watch and notify for Mongodb Replicasets health
# Monitor more than one mongodb instance per host
# Watch DiskIO counters - it runs well with outstanding third party Iostat-Disk-Utilization-Template
(https://github.com/lesovsky/zabbix-extensions/tree/master/files/iostat)
# Provide easy-to-use and easy-to-understand user view for staff.

Technically, for fine mongodb performance tuning you need much more information than provides this templates, but its harder to 
collect, store and visualize with Zabbix, and anyway will be better for you to use specially designed mongodb tools for it. 
Google it for more information.


