#! /usr/bin/env ruby
#
#   check-mongodb-metric.rb
#
# DESCRIPTION:
#
# OUTPUT:
#   plain text
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
#
# LICENSE:
#   Copyright 2016 Conversocial https://github.com/conversocial
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'sensu-plugins-mongodb/metics'
require 'mongo'
include Mongo

#
# Mongodb
#

class CheckMongodbMetric < Sensu::Plugin::Check::CLI
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

  option :require_master,
         description: 'Require the node to be a master node',
         long: '--require-master',
         default: false

  option :metric,
         description: 'Name of the metric to check',
         long: '--metric METRIC',
         short: '-m METRIC'

  option :warn,
         description: 'Warn if values are above this threshold',
         short: '-w WARN',
         proc: proc(&:to_i),
         default: 0

  option :crit,
         description: 'Fail if values are above this threshold',
         short: '-c CRIT',
         proc: proc(&:to_i),
         default: 0

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

    # Make sure the requested value is available.
    unless metrics.key?(config[:metric])
      unknown "Unable to find a value for metric '#{config[:metric]}'"
    end

    # Check the requested value against the thresholds.
    value = metrics[config[:metric]]
    if value >= config[:crit]
      critical "The value of '#{config[:metric]}' exceeds #{config[:crit]}."
    end
    if value >= config[:warn]
      warning "The value of '#{config[:metric]}' exceeds #{config[:warn]}."
    end
    ok "The value of '#{config[:metric]}' is below all threshold."
  end
end
