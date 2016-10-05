#! /usr/bin/env ruby
#
#   metrics-mongodb.rb
#
# DESCRIPTION:
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: mongo
#   gem: bson
#   gem: bson_ext
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   Basics from github.com/mantree/mongodb-graphite-metrics
#
# LICENSE:
#   Copyright 2013 github.com/foomatty
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'sensu-plugins-mongodb/metics'
require 'mongo'
include Mongo

#
# Mongodb
#

class MongoDB < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         description: 'MongoDB host',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'MongoDB port',
         long: '--port PORT',
         default: 27_017

  option :user,
         description: 'MongoDB user',
         long: '--user USER',
         default: nil

  option :password,
         description: 'MongoDB password',
         long: '--password PASSWORD',
         default: nil

  option :ssl,
         description: 'Connect using SSL',
         long: '--ssl',
         default: false

  option :ssl_cert,
         description: 'The certificate file used to identify the local connection against mongod',
         long: '--ssl-cert SSL_CERT',
         default: ''

  option :ssl_key,
         description: 'The private key used to identify the local connection against mongod',
         long: '--ssl-key SSL_KEY',
         default: ''

  option :ssl_ca_cert,
         description: 'The set of concatenated CA certificates, which are used to validate certificates passed from the other end of the connection',
         long: '--ssl-ca-cert SSL_CA_CERT',
         default: ''

  option :ssl_verify,
         description: 'Whether or not to do peer certification validation',
         long: '--ssl-verify',
         default: false

  option :debug,
         description: 'Enable debug',
         long: '--debug',
         default: false

  option :scheme,
         description: 'Metric naming scheme',
         long: '--scheme SCHEME',
         short: '-s SCHEME',
         default: "#{Socket.gethostname}.mongodb"

  option :require_master,
         description: 'Require the node to be a master node',
         long: '--require-master',
         default: false

  def run
    Mongo::Logger.logger.level = Logger::FATAL
    @debug = config[:debug]
    if @debug
      Mongo::Logger.logger.level = Logger::DEBUG
      config_debug = config.clone
      config_debug[:password] = '***'
      puts 'Arguments: ' + config_debug.inspect
    end

    # Get the metrics.
    collector = SensuPluginsMongoDB::Metrics.new(config)
    collector.connect_mongo_db('admin')
    exit(1) if config[:require_master] && !collector.master?
    metrics = collector.server_metrics

    # Print them in graphite format.
    timestamp = Time.now.to_i
    metrics.each do |k, v|
      output [config[:scheme], k].join('.'), v, timestamp
    end

    # done!
    ok
  end
end
