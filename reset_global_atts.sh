#!/bin/bash

psql doit -U doit -c 'update global_attributes set id = (select tag_id from golf.goby_global_schema where name = tag_code);'
