s/^.*CASEMANAGEMENT.*[:=].*$/CASEMANAGEMENT=all/
s;^.*DOCUMENT_DIR.*[:=].*$;DOCUMENT_DIR = /var/lib/tomcat6/webapps/OscarDocument/oscar_mcmaster/document/;
s;^.*eform_imag.*[:=].*$;eform_image = /var/lib/tomcat6/webapps/OscarDocument/oscar_mcmaster/eform/images;
s;^.*TMP_DIR.*[:=].*$;TMP_DIR: /var/lib/tomcat6/webapps/OscarDocument/oscar_mcmaster/export/;
s/^.*db_name.*[:=].*$/db_name = oscar_12_1/
s/^.*db_password.*[:=].*$/db_password=xxxx/
s/^.*visitlocation.*[:=].*$/visitlocation = 00|VANCOUVER/
s/^.*dataCenterId.*[:=].*$/dataCenterId = 00000/
s/^.*billregion.*[:=].*$/billregion=BC/
s/^.*NEW_BC_TELEPLAN.*[:=].*$/NEW_BC_TELEPLAN=yes/
s/^.*CDM_ALERTS.*[:=].*$/CDM_ALERTS=250,428,4280/
s/^.*COUNSELING_CODES.*[:=].*$/COUNSELING_CODES=18220,18120,17220,17120,16220,16120,13220,12220,12120,00120/
s/^.*phoneprefix.*[:=].*$/phoneprefix = 250-/
/drugref_url/s/^/#/
