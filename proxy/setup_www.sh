#!/usr/bin/env bash
# Setup openssl infra:

#Create ROOT-CA
#Create server - cert
#Create n*client certs
#Create n*revocation lists
#n* means you can call the script again and create a new client & clr


SUBJ="/C=DE/O=documentix"

HOST="${1:-$(hostname -f)}"
CNAME="${2:-User}"
CRLURL="http://${HOST}/ca.crl"
ALTNAMES="DNS:${HOST}"


if [ ! -d pki ]; then 
	rm -rf pki CA clients 
	mkdir pki clients CA 
	echo -n "100001234567" >pki/serial
	touch pki/index.txt
	mkdir -p pki/newcerts

	echo "********************************************************"
	echo "* Create openssl configureation -- minimal             *"
	echo "********************************************************"
	cat  >openssl.cnf <<-END_OF_CONF

	[ ca ]
	default_ca	= CA_default		# The default ca section

	[ CA_default ]

	dir		= pki		# Where everything is kept
        CA              = CA
	certs		= \$dir/certs		# Where the issued certs are kept
	crl_dir		= \$dir/crl		# Where the issued crl are kept
	database	= \$dir/index.txt	# database index file.
	unique_subject	= no			# Set to 'no' to allow creation of
						# several ctificates with same subject.
	new_certs_dir	= \$dir/newcerts		# default place for new certs.

	certificate	= \$CA/ca_cert.pem 	# The CA certificate
	serial		= \$dir/serial 		# The current serial number
	crlnumber	= \$dir/crlnumber	# the current crl number
						# must be commented out to leave a V1 CRL
	crl		= \$dir/crl.pem 	# The current CRL
	private_key	= \$CA/ca_rsa.key       # The private key
	RANDFILE	= \$dir/private/.rand	# private random number file
	x509_extensions	= usr_cert		# The extentions to add to the cert


	# Comment out the following two lines for the "traditional"
	# (and highly broken) format.
	name_opt 	= ca_default		# Subject Name options
	cert_opt 	= ca_default		# Certificate field options

	default_days	= 365			# how long to certify for
	default_crl_days= 30			# how long before next CRL
	default_md	= default		# use public key default MD
	preserve	= no			# keep passed DN ordering

	distinguished_name      = req_distinguished_name
	# attributes              = req_attributes
	policy          = policy_anything

	[ req_distinguished_name ]

	[ req ]
	distinguished_name      = req_distinguished_name

	[ policy_anything ]
	countryName             = match
	stateOrProvinceName     = optional
	organizationName        = match
	organizationalUnitName  = optional
	commonName              = supplied

	[ srv_cert ]

	basicConstraints=critical, CA:FALSE
	keyUsage = critical,  digitalSignature, keyEncipherment
	extendedKeyUsage=serverAuth, clientAuth
	# PKIX recommendations harmless if included in all certificates.
	subjectKeyIdentifier=hash
	authorityKeyIdentifier=keyid,issuer

	nsCaRevocationUrl              = ${CRLURL}
	nsRevocationUrl 		= ${CRLURL}
        crlDistributionPoints=URI:${CRLURL}
	subjectAltName=${ALTNAMES}
        certificatePolicies=ia5org,1.2.3.4,1.5.6.7.8,@polsect

        [polsect]

        policyIdentifier = 1.3.5.8
        CPS.1="http://www.nispuk.com/"
        userNotice.1=@notice

        [notice]

        explicitText="Forget about all warantee"
        organization="Documentix"
        noticeNumbers=1,2,3,4


	[ ca_cert ]

	basicConstraints=critical,CA:TRUE, pathlen:0
	subjectKeyIdentifier=hash
	authorityKeyIdentifier=keyid,issuer

	[ usr_cert ]

	basicConstraints=CA:FALSE
	# nsCertType = client, email, objsign

	# This is typical in keyUsage for a client certificate.
	keyUsage = nonRepudiation, digitalSignature, keyEncipherment
	extendedKeyUsage=clientAuth

	# PKIX recommendations harmless if included in all certificates.
	subjectKeyIdentifier=hash
	authorityKeyIdentifier=keyid,issuer

	nsCaRevocationUrl              = ${CRLURL}
	nsRevocationUrl 		= ${CRLURL}


END_OF_CONF



	#Generate CA cert:
	echo "********************************************************"
	echo "* Setup a certifiaction authority                      *"
	echo "********************************************************"

	openssl genrsa   -out CA/ca_rsa.key -f4 2048
	openssl req -config openssl.cnf -extensions ca_cert -new  -x509 -subj "${SUBJ}/CN=documentix-ca" -days 3650 -out CA/ca_cert.pem -key CA/ca_rsa.key

	echo "********************************************************"
	echo "* Setup a web-server signing entity                               *"
	echo "********************************************************"

	#Generate Signing-cert
	openssl genrsa   -out clients/server.key -f4 2048
	openssl req -config openssl.cnf -new  -subj "${SUBJ}/CN=${HOST}"  -out new.req -key clients/server.key

	#Ask the CA to sign
	openssl ca -batch -config openssl.cnf -extensions srv_cert -in new.req -out clients/server.pem
	rm new.req
        cat clients/server.* >server.pem
	echo 0001 >pki/crlnumber

fi
echo "********************************************************"
echo "* Generate/update initial CRL                                 *"
echo "********************************************************"
openssl ca -batch -config openssl.cnf -gencrl -cert CA/ca_cert.pem -keyfile CA/ca_rsa.key -out CA/ca.crl  

if [ ! -f "${CNAME}.pem" ]; then
	echo "********************************************************"
	echo "* Setup a client entity                               *"
	echo "********************************************************"

	#Generate Signing-cert
	openssl genrsa   -out clients/${CNAME}.key -f4 2048
	openssl req -config openssl.cnf -new  -subj "${SUBJ}/CN=${CNAME}"  -out new.req -key clients/${CNAME}.key

	#Ask the CA to sign
	openssl ca -batch -config openssl.cnf -in new.req -out clients/${CNAME}.pem
	rm new.req

	#Create P12 user cert
	echo
	echo "Please ensure: CA/ca.crl is stored in ${CRLURL}" >&2
	echo "Pkcs12 file: ${CNAME}.p12"
	echo -n "Password: "
	openssl rand  -base64 18 | tee /dev/tty |
	openssl pkcs12 -inkey clients/${CNAME}.key -certfile CA/ca_cert.pem -export -in clients/${CNAME}.pem -out ${CNAME}.p12 -passout stdin
fi

