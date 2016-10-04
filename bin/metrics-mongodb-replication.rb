#! /usr/bin/env ruby
#
#   metrics-mongodb-replication.rb
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
# NOTES::
#   Basics from github.com/sensu-plugins/sensu-plugins-mongodb/bin/metrics-mongodb
#
#   Replication lag is calculated by obtaining the last optime from primary and
#   secondary members. The last optime of the secondary is subtracted from the
#   last optime of the primary to produce the difference in seconds, minutes and hours
#
# LICENSE:
#   Copyright 2016 Rycroft Solutions
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'mongo'
require 'date'
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

  option :scheme,
         description: 'Metric naming scheme',
         long: '--scheme SCHEME',
         short: '-s SCHEME',
         default: "#{Socket.gethostname}.mongodb"

  option :password,
         description: 'MongoDB password',
         long: '--password PASSWORD',
         default: nil

  option :debug,
         description: 'Enable debug',
         long: '--debug',
         default: false

  def get_mongo_doc(command)
    rs = @db.command(command)
    unless rs.successful?
      return nil
    end
    rs.documents[0]
  end

  # connects to mongo and sets @db, works with MongoClient < 2.0.0
  def connect_mongo_db
    if Gem.loaded_specs['mongo'].version < Gem::Version.new('2.0.0')
      mongo_client = MongoClient.new(host, port)
      @db = mongo_client.db(db_name)
      @db.authenticate(db_user, db_password) unless db_user.nil?
    else
      address_str = "#{config[:host]}:#{config[:port]}"
      client_opts = {}
      client_opts[:database] = 'admin'
      unless config[:user].nil?
        client_opts[:user] = config[:user]
        client_opts[:password] = config[:password]
      end
      if config[:ssl]
        client_opts[:ssl] = true
        client_opts[:ssl_cert] = config[:ssl_cert]
        client_opts[:ssl_key] = config[:ssl_key]
        client_opts[:ssl_ca_cert] = config[:ssl_ca_cert]
        client_opts[:ssl_verify] = config[:ssl_verify]
      end
      mongo_client = Mongo::Client.new([address_str], client_opts)
      @db = mongo_client.database
    end
  end

  def run
    Mongo::Logger.logger.level = Logger::FATAL
    @debug = config[:debug]
    if @debug
      Mongo::Logger.logger.level = Logger::DEBUG
      config_debug = config.clone
      config_debug[:password] = '***'
      puts 'arguments:' + config_debug.inspect
    end

    connect_mongo_db

    _result = false
    # check if master
    begin
      @is_master = get_mongo_doc('isMaster' => 1)
      unless @is_master.nil?
        _result = @is_master['ok'] == 1
      end
    rescue StandardError => e
      if @debug
        puts 'Error checking isMaster:' + e.message
        puts e.backtrace.inspect
      end
      exit(1)
    end

    replication_status = get_mongo_doc('replSetGetStatus' => 1)

    # get the replication metrics
    begin
      metrics = {}
      if !replication_status.nil? && replication_status['ok'] == 1
        metrics.update(gather_replication_metrics(replication_status))
        timestamp = Time.now.to_i
        metrics.each do |k, v|
          unless v.nil?
            output [config[:scheme], 'replication', k].join('.'), v, timestamp
          end
        end
      end
    rescue StandardError => e
      if @debug
        puts 'Error checking replicationStatus:' + e.message
        puts e.backtrace.inspect
      end
      exit(2)
    end

    # Get the repllication member metrics
    begin
      metrics = {}
      replication_members = replication_status['members']
      unless replication_members.nil?
        replication_members.each do |replication_member_details|
          metrics.update(gather_replication_member_metrics(replication_member_details))
          member_id = replication_member_details['_id']
          timestamp = Time.now.to_i
          metrics.each do |k, v|
            unless v.nil?
              output [config[:scheme], "member_#{member_id}", k].join('.'), v, timestamp
            end
          end
        end
      end
    rescue StandardError => e
      if @debug
        puts 'Error checking replicationMemberStatus:' + e.message
        puts e.backtrace.inspect
      end
      exit(2)
    end

    # done!
    ok
  end

  def gather_replication_metrics(replication_status)
    replication_metrics = {}

    replication_metrics['replica_set'] = replication_status['set']
    replication_metrics['date'] = replication_status['date']
    replication_metrics['myState'] = replication_status['myState']
    replication_metrics['term'] = replication_status['term']
    replication_metrics['heartbeatIntervalMillis'] = replication_status['heartbeatIntervalMillis']

    replication_metrics
  end

  def gather_replication_member_metrics(replication_member_details)
    replication_member_metrics = {}

    replication_member_metrics['id'] = replication_member_details['_id']
    replication_member_metrics['name'] = replication_member_details['name']
    replication_member_metrics['health'] = replication_member_details['health']
    replication_member_metrics['state'] = replication_member_details['state']
    replication_member_metrics['stateStr'] = replication_member_details['stateStr']
    member_hierarchy = replication_member_details['stateStr']
    if member_hierarchy == 'PRIMARY'
      @primary_optime_date = replication_member_details['optimeDate']
      replication_member_metrics['primary.startOptimeDate'] = @primary_optime_date
    end
    if member_hierarchy == 'SECONDARY'
      @secondary_optime_date = replication_member_details['optimeDate']
      difference_in_seconds = (@primary_optime_date - @secondary_optime_date).to_i
      difference_in_minutes = ((@primary_optime_date - @secondary_optime_date) / 60).to_i
      difference_in_hours = ((@primary_optime_date - @secondary_optime_date) / 3600).to_i
      replication_member_metrics['secondsBehindPrimary'] = difference_in_seconds
      replication_member_metrics['minutesBehindPrimary'] = difference_in_minutes
      replication_member_metrics['hoursBehindPrimary'] = difference_in_hours
    end
    replication_member_metrics['optimeDate'] = replication_member_details['optimeDate']
    replication_member_metrics['uptime'] = replication_member_details['uptime']
    replication_member_metrics['lastHeartbeat'] = replication_member_details['lastHeartbeat']
    replication_member_metrics['lastHeartbeatRecv'] = replication_member_details['lastHeartbeatiRecv']
    replication_member_metrics['pingMs'] = replication_member_details['pingMs']
    replication_member_metrics['syncingTo'] = replication_member_details['syncingTo']
    replication_member_metrics['configVersion'] = replication_member_details['configVersion']

    replication_member_metrics
  end
end
