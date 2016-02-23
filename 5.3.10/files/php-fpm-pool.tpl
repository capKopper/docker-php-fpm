[{{ CUSTOMER }}]
listen = 0.0.0.0:9000
user = {{ CUSTOMER }}
group = {{ CUSTOMER }}

pm = dynamic
pm.max_children = 5
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.start_servers = 2
pm.status_path = /status

ping.path = /ping
ping.response = pong

access.log = /var/log/php5-fpm/$pool.access.log
access.format = "%R - %u %t \"%m %r%Q%q\" %s %f %{mili}d %{kilo}M %C%%"

php_flag[expose_php] = off
php_value[max_execution_time] = {{ PHP_FPM_MAX_EXECUTION_TIME }}
php_value[memory_limit] = {{ PHP_FPM_MEMORY_LIMIT }}
