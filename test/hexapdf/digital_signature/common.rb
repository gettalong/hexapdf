require 'openssl'

module HexaPDF
  module TestUtils

    class Certificates

      # Port for the combined OCSP responder / CRL distribution point test server.
      OCSP_CRL_PORT = 34568

      def ca_key
        @ca_key ||= OpenSSL::PKey::RSA.new(2048)
      end

      def ca_certificate
        @ca_certificate ||=
          begin
            cert = create_cert(name: '/C=AT/O=HexaPDF/CN=HexaPDF Test Root CA', serial: 0,
                               public_key: ca_key)
            add_extensions(cert, cert, ca_key, is_ca: true, key_usage: 'cRLSign,keyCertSign')
            cert
          end
      end

      def signer_key
        @signer_key ||= OpenSSL::PKey::RSA.new(2048)
      end

      def signer_certificate
        @signer_certificate ||=
          begin
            cert = create_cert(name: '/CN=RSA signer', serial: 1,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature')
            cert
          end
      end

      def non_repudiation_signer_certificate
        @non_repudiation_signer_certificate ||=
          begin
            cert = create_cert(name: '/CN=Non repudiation signer', serial: 2,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'nonRepudiation')
            cert
          end
      end

      def signer_certificate_with_ocsp
        @signer_certificate_with_ocsp ||=
          begin
            cert = create_cert(name: '/CN=RSA signer with OCSP', serial: 6,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           ocsp_url: "http://127.0.0.1:#{OCSP_CRL_PORT}/ocsp")
            cert
          end
      end

      def signer_certificate_with_crl
        @signer_certificate_with_crl ||=
          begin
            cert = create_cert(name: '/CN=RSA signer with CRL', serial: 7,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           crl_url: "http://127.0.0.1:#{OCSP_CRL_PORT}/crl")
            cert
          end
      end

      def signer_certificate_with_unsuccessful_ocsp
        @signer_certificate_with_unsuccessful_ocsp ||=
          begin
            cert = create_cert(name: '/CN=RSA signer with unsucessful OCSP', serial: 11,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           ocsp_url: "http://127.0.0.1:#{OCSP_CRL_PORT}/ocsp-unsuccessful")
            cert
          end
      end

      def signer_certificate_with_revoked_ocsp
        @signer_certificate_with_revoked_ocsp ||=
          begin
            cert = create_cert(name: '/CN=RSA signer with revoked OCSP', serial: 12,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           ocsp_url: "http://127.0.0.1:#{OCSP_CRL_PORT}/ocsp-revoked")
            cert
          end
      end

      def signer_certificate_with_http_error_ocsp
        @signer_certificate_with_http_error_ocsp ||=
          begin
            cert = create_cert(name: '/CN=RSA signer with HTTP error OCSP', serial: 13,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           ocsp_url: "http://127.0.0.1:#{OCSP_CRL_PORT}/ocsp-http-error")
            cert
          end
      end

      def signer_certificate_with_bad_ocsp
        @signer_certificate_with_bad_ocsp ||=
          begin
            cert = create_cert(name: '/CN=RSA signer with bad OCSP', serial: 8,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           ocsp_url: "http://127.0.0.1:#{OCSP_CRL_PORT + 1}/ocsp")
            cert
          end
      end

      def signer_certificate_with_revoked_crl
        @signer_certificate_with_revoked_crl ||=
          begin
            cert = create_cert(name: '/CN=RSA signer with revoked CRL', serial: 14,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           crl_url: "http://127.0.0.1:#{OCSP_CRL_PORT}/crl-revoked")
            cert
          end
      end

      def signer_certificate_with_http_error_crl
        @signer_certificate_with_http_error_crl ||=
          begin
            cert = create_cert(name: '/CN=RSA signer with HTTP error CRL', serial: 15,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           crl_url: "http://127.0.0.1:#{OCSP_CRL_PORT}/crl-http-error")
            cert
          end
      end

      def signer_certificate_with_bad_crl
        @signer_certificate_with_bad_crl ||=
          begin
            cert = create_cert(name: '/CN=RSA signer with bad CRL', serial: 9,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           crl_url: "http://127.0.0.1:#{OCSP_CRL_PORT + 1}/crl")
            cert
          end
      end


      def dsa_signer_key
        @dsa_signer_key ||= OpenSSL::PKey::DSA.new(2048)
      end

      def dsa_signer_certificate
        @dsa_signer_certificate ||=
          begin
            cert = create_cert(name: '/CN=DSA signer', serial: 3,
                               public_key: dsa_signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature')
            cert
          end
      end

      def ecdsa_signer_key
        @ecdsa_signer_key ||= OpenSSL::PKey::EC.generate('sect163k1')
      end

      def ecdsa_signer_certificate
        @ecdsa_signer_certificate ||=
          begin
            cert = create_cert(name: '/CN=ECDSA signer', serial: 4,
                               public_key: ecdsa_signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature')
            cert
          end
      end

      def timestamp_certificate
        @timestamp_certificate ||=
          begin
            cert = create_cert(name: '/CN=timestamp', serial: 5,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           extended_key_usage: 'timeStamping',
                           crl_url: "http://127.0.0.1:#{OCSP_CRL_PORT}/crl")
            cert
          end
      end

      def ocsp_signing_certificate
        @ocsp_signing_certificate ||=
          begin
            cert = create_cert(name: '/CN=OCSP', serial: 10,
                               public_key: signer_key, issuer: ca_certificate)
            add_extensions(cert, ca_certificate, ca_key, key_usage: 'digitalSignature',
                           extended_key_usage: 'OCSPSigning')
            cert
          end
      end

      def crl
        @crl ||=
          begin
            crl = OpenSSL::X509::CRL.new
            crl.version = 1
            crl.issuer = ca_certificate.subject
            crl.last_update = Time.now - 60
            crl.next_update = Time.now + 86400
            crl.sign(ca_key, OpenSSL::Digest.new('SHA256'))
            crl
          end
      end

      def create_cert(name:, serial:, public_key:, issuer: nil)
        name = OpenSSL::X509::Name.parse(name)
        cert = OpenSSL::X509::Certificate.new
        cert.serial = serial
        cert.version = 2
        cert.not_before = Time.now - 86400
        cert.not_after = Time.now + 86400
        cert.public_key = public_key
        cert.subject = name
        cert.issuer = (issuer ? issuer.subject : name)
        cert
      end

      def add_extensions(subject_cert, issuer_cert, signing_key, is_ca: false, key_usage: nil,
                         extended_key_usage: nil, ocsp_url: nil, crl_url: nil)
        extension_factory = OpenSSL::X509::ExtensionFactory.new
        extension_factory.subject_certificate = subject_cert
        extension_factory.issuer_certificate = issuer_cert
        subject_cert.add_extension(extension_factory.create_extension('subjectKeyIdentifier', 'hash'))
        if is_ca
          subject_cert.add_extension(extension_factory.create_extension('basicConstraints', 'CA:TRUE', true))
        else
          subject_cert.add_extension(extension_factory.create_extension('basicConstraints', 'CA:FALSE'))
        end
        if key_usage
          subject_cert.add_extension(extension_factory.create_extension('keyUsage', key_usage, true))
        end
        if extended_key_usage
          subject_cert.add_extension(extension_factory.create_extension('extendedKeyUsage',
                                                                        extended_key_usage, true))
        end
        if ocsp_url
          subject_cert.add_extension(
            extension_factory.create_extension('authorityInfoAccess', "OCSP;URI:#{ocsp_url}")
          )
        end
        if crl_url
          subject_cert.add_extension(
            extension_factory.create_extension('crlDistributionPoints', "URI:#{crl_url}")
          )
        end
        subject_cert.sign(signing_key, OpenSSL::Digest.new('SHA1'))
      end
      private :add_extensions

      def start_tsa_server
        return if defined?(@tsa_server)
        require 'webrick'
        port = 34567
        @tsa_server = WEBrick::HTTPServer.new(Port: port, BindAddress: '127.0.0.1',
                                              Logger: WEBrick::Log.new(StringIO.new), AccessLog: [])
        @tsa_server.mount_proc('/') do |request, response|
          @tsr = OpenSSL::Timestamp::Request.new(request.body)
          case @tsr.policy_id || '1.2.3.4.0'
          when '1.2.3.4.0', '1.2.3.4.2', '1.2.3.4.3'
            if @tsr.policy_id == '1.2.3.4.3'
              WEBrick::HTTPAuth.basic_auth(request, response, 'HexaPDF Auth') do |username, password|
                username == 'hexatest' && password == 'hexapwd'
              end
            end
            fac = OpenSSL::Timestamp::Factory.new
            fac.gen_time = Time.now
            fac.serial_number = 1
            fac.default_policy_id = '1.2.3.4.5'
            fac.allowed_digests = ["sha256", "sha512"]
            tsr = fac.create_timestamp(CERTIFICATES.signer_key, CERTIFICATES.timestamp_certificate,
                                       @tsr)
            response.body = tsr.to_der
          when '1.2.3.4.1'
            response.status = 403
            response.body = "Invalid"
          end
        end
        Thread.new { @tsa_server.start }
      end

      def start_ocsp_crl_server
        return if defined?(@ocsp_crl_server)
        require 'webrick'
        @ocsp_crl_server = WEBrick::HTTPServer.new(Port: OCSP_CRL_PORT, BindAddress: '127.0.0.1',
                                                   Logger: WEBrick::Log.new(StringIO.new), AccessLog: [])
        @ocsp_crl_server.mount_proc('/ocsp') do |request, response|
          ocsp_req = OpenSSL::OCSP::Request.new(request.body)
          basic_resp = OpenSSL::OCSP::BasicResponse.new
          ocsp_req.certid.each do |certid|
            basic_resp.add_status(certid, OpenSSL::OCSP::V_CERTSTATUS_GOOD,
                                  OpenSSL::OCSP::REVOKED_STATUS_UNSPECIFIED,
                                  nil, Time.now - 60, Time.now + 86400, nil)
          end
          basic_resp.sign(CERTIFICATES.ocsp_signing_certificate, CERTIFICATES.signer_key,
                          [CERTIFICATES.ca_certificate])
          response.body = OpenSSL::OCSP::Response.create(
            OpenSSL::OCSP::RESPONSE_STATUS_SUCCESSFUL, basic_resp
          ).to_der
          response['Content-Type'] = 'application/ocsp-response'
        end

        @ocsp_crl_server.mount_proc('/ocsp-unsuccessful') do |request, response|
          basic_resp = OpenSSL::OCSP::BasicResponse.new
          basic_resp.sign(CERTIFICATES.ocsp_signing_certificate, CERTIFICATES.signer_key,
                          [CERTIFICATES.ca_certificate])
          response.body = OpenSSL::OCSP::Response.create(
            OpenSSL::OCSP::RESPONSE_STATUS_INTERNALERROR, basic_resp
          ).to_der
          response['Content-Type'] = 'application/ocsp-response'
        end

        @ocsp_crl_server.mount_proc('/ocsp-revoked') do |request, response|
          ocsp_req = OpenSSL::OCSP::Request.new(request.body)
          basic_resp = OpenSSL::OCSP::BasicResponse.new
          ocsp_req.certid.each do |certid|
            basic_resp.add_status(certid, OpenSSL::OCSP::V_CERTSTATUS_REVOKED,
                                  OpenSSL::OCSP::REVOKED_STATUS_UNSPECIFIED,
                                  Time.now - 100, Time.now - 60, Time.now + 86400, nil)
          end
          basic_resp.sign(CERTIFICATES.ocsp_signing_certificate, CERTIFICATES.signer_key,
                          [CERTIFICATES.ca_certificate])
          response.body = OpenSSL::OCSP::Response.create(
            OpenSSL::OCSP::RESPONSE_STATUS_SUCCESSFUL, basic_resp
          ).to_der
          response['Content-Type'] = 'application/ocsp-response'
        end

        @ocsp_crl_server.mount_proc('/crl') do |_request, response|
          response.body = CERTIFICATES.crl.to_der
          response['Content-Type'] = 'application/pkix-crl'
        end

        @ocsp_crl_server.mount_proc('/crl-revoked') do |_request, response|
          crl = OpenSSL::X509::CRL.new
          crl.version = 1
          crl.issuer = ca_certificate.subject
          crl.last_update = Time.now - 60
          crl.next_update = Time.now + 86400
          revoked = OpenSSL::X509::Revoked.new
          revoked.serial = signer_certificate_with_revoked_crl.serial
          revoked.time = Time.now - 100
          crl.add_revoked(revoked)
          crl.sign(ca_key, OpenSSL::Digest.new('SHA256'))
          response.body = crl.to_der
          response['Content-Type'] = 'application/pkix-crl'
        end
        Thread.new { @ocsp_crl_server.start }
      end

    end

  end
end

CERTIFICATES = HexaPDF::TestUtils::Certificates.new
