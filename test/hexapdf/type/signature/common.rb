require 'openssl'

module HexaPDF
  module TestUtils

    class Certificates

      def ca_key
        @ca_key ||= OpenSSL::PKey::RSA.new(512)
      end

      def ca_certificate
        @ca_certificate ||=
          begin
            ca_name = OpenSSL::X509::Name.parse('/C=AT/O=HexaPDF/CN=HexaPDF Test Root CA')

            ca_cert = OpenSSL::X509::Certificate.new
            ca_cert.serial = 0
            ca_cert.version = 2
            ca_cert.not_before = Time.now - 86400
            ca_cert.not_after = Time.now + 86400
            ca_cert.public_key = ca_key.public_key
            ca_cert.subject = ca_name
            ca_cert.issuer = ca_name

            extension_factory = OpenSSL::X509::ExtensionFactory.new
            extension_factory.subject_certificate = ca_cert
            extension_factory.issuer_certificate = ca_cert
            ca_cert.add_extension(extension_factory.create_extension('subjectKeyIdentifier', 'hash'))
            ca_cert.add_extension(extension_factory.create_extension('basicConstraints', 'CA:TRUE', true))
            ca_cert.add_extension(extension_factory.create_extension('keyUsage', 'cRLSign,keyCertSign', true))
            ca_cert.sign(ca_key, OpenSSL::Digest.new('SHA1'))

            ca_cert
          end
      end

      def signer_key
        @signer_key ||= OpenSSL::PKey::RSA.new(512)
      end

      def signer_certificate
        @signer_certificate ||=
          begin
            name = OpenSSL::X509::Name.parse('/CN=signer/DC=gettalong')

            signer_cert = OpenSSL::X509::Certificate.new
            signer_cert.serial = 2
            signer_cert.version = 2
            signer_cert.not_before = Time.now - 86400
            signer_cert.not_after = Time.now + 86400
            signer_cert.public_key = signer_key.public_key
            signer_cert.subject = name
            signer_cert.issuer = ca_certificate.subject

            extension_factory = OpenSSL::X509::ExtensionFactory.new
            extension_factory.subject_certificate = signer_cert
            extension_factory.issuer_certificate = ca_certificate
            signer_cert.add_extension(extension_factory.create_extension('subjectKeyIdentifier', 'hash'))
            signer_cert.add_extension(extension_factory.create_extension('basicConstraints', 'CA:FALSE'))
            signer_cert.add_extension(extension_factory.create_extension('keyUsage', 'digitalSignature'))
            signer_cert.sign(ca_key, OpenSSL::Digest.new('SHA1'))

            signer_cert
          end
      end

      def timestamp_certificate
        @timestamp_certificate ||=
          begin
            name = OpenSSL::X509::Name.parse('/CN=timestamp/DC=gettalong')

            signer_cert = OpenSSL::X509::Certificate.new
            signer_cert.serial = 3
            signer_cert.version = 2
            signer_cert.not_before = Time.now - 86400
            signer_cert.not_after = Time.now + 86400
            signer_cert.public_key = signer_key.public_key
            signer_cert.subject = name
            signer_cert.issuer = ca_certificate.subject

            extension_factory = OpenSSL::X509::ExtensionFactory.new
            extension_factory.subject_certificate = signer_cert
            extension_factory.issuer_certificate = ca_certificate
            signer_cert.add_extension(extension_factory.create_extension('subjectKeyIdentifier', 'hash'))
            signer_cert.add_extension(extension_factory.create_extension('basicConstraints', 'CA:FALSE'))
            signer_cert.add_extension(extension_factory.create_extension('keyUsage', 'digitalSignature'))
            signer_cert.add_extension(extension_factory.create_extension('extendedKeyUsage', 'timeStamping', true))
            signer_cert.sign(ca_key, OpenSSL::Digest.new('SHA1'))

            signer_cert
          end
      end
    end

  end
end

CERTIFICATES = HexaPDF::TestUtils::Certificates.new
