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
  def connect_mongo_db(host, port, db_name, db_user, db_password)
    if Gem.loaded_specs['mongo'].version < Gem::Version.new('2.0.0')
      mongo_client = MongoClient.new(host, port)
      @db = mongo_client.db(db_name)
      @db.authenticate(db_user, db_password) unless db_user.nil?
    else
      address_str = "#{host}:#{port}"
      client_opts = {}
      client_opts[:database] = db_name
      unless db_user.nil?
        client_opts[:user] = db_user
        client_opts[:password] = db_password
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
    host = config[:host]
    port = config[:port]
    db_name = 'admin'
    db_user = config[:user]
    db_password = config[:password]

    connect_mongo_db(host, port, db_name, db_user, db_password)

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

    # get the metrics
    begin
      metrics = {}
      server_status = get_mongo_doc('serverStatus' => 1)
      if !server_status.nil? && server_status['ok'] == 1
        metrics.update(gather_replication_metrics(server_status))
        timestamp = Time.now.to_i
        metrics.each do |k, v|
          output [config[:scheme], k].join('.'), v, timestamp
        end
      end
    rescue StandardError => e
      if @debug
        puts 'Error checking serverStatus:' + e.message
        puts e.backtrace.inspect
      end
      exit(2)
    end

    # done!
    ok
  end

  def gather_replication_metrics(server_status)
    mongo_version = server_status['version'].gsub(/[^0-9\.]/i, '') # Handle versions like "2.6.11-pre" etc
    server_metrics = {}

    server_metrics['lock.ratio'] = sprintf('%.5f', server_status['globalLock']['ratio']).to_s unless server_status['globalLock']['ratio'].nil?

    # Asserts
    server_metrics['asserts_warnings'] = server_status['asserts']['warning']
    server_metrics['asserts_errors'] = server_status['asserts']['msg']
    server_metrics['asserts_regular'] = server_status['asserts']['regular']
    server_metrics['asserts_user'] = server_status['asserts']['user']
    server_metrics['asserts_rollovers'] = server_status['asserts']['rollovers']

    # Background flushing
    server_metrics['backgroundFlushing_flushes'] = server_status['backgroundFlushing']['flushes']
    server_metrics['backgroundFlushing_total_ms'] = server_status['backgroundFlushing']['total_ms']
    server_metrics['backgroundFlushing_average_ms'] = server_status['backgroundFlushing']['average_ms']
    server_metrics['backgroundFlushing_last_ms'] = server_status['backgroundFlushing']['last_ms']

    # Connections
    server_metrics['connections_current'] = server_status['connections']['current']
    server_metrics['connections_available'] = server_status['connections']['available']
    server_metrics['connections_totalCreated'] = server_status['connections']['totalCreated']

    # Cursors
    server_metrics['clientCursors_size'] = server_status['cursors']['clientCursors_size']
    server_metrics['cursors_open'] = server_status['cursors']['totalOpen']
    server_metrics['cursors_pinned'] = server_status['cursors']['pinned']
    server_metrics['cursors_totalNoTimeout'] = server_status['cursors']['totalNoTimeout']
    server_metrics['cursors_timedOut'] = server_status['cursors']['timedOut']

    # Journaling (durability)
    server_metrics['journal_commits'] = server_status['dur']['commits']
    server_metrics['journaled_MB'] = server_status['dur']['journaledMB']
    server_metrics['journal_timeMs_writeToDataFiles'] = server_status['dur']['timeMs']['writeToDataFiles'] 
    server_metrics['journal_writeToDataFilesMB'] = server_status['dur']['writeToDataFilesMB']
    server_metrics['journal_compression'] = server_status['dur']['compression']
    server_metrics['journal_commitsInWriteLock'] = server_status['dur']['commitsInWriteLock']
    server_metrics['journal_timeMs_dt'] = server_status['dur']['timeMs']['dt'] 
    server_metrics['journal_timeMs_prepLogBuffer'] = server_status['dur']['timeMs']['prepLogBuffer'] 
    server_metrics['journal_timeMs_writeToJournal'] = server_status['dur']['timeMs']['writeToJournal'] 
    server_metrics['journal_timeMs_remapPrivateView'] = server_status['dur']['timeMs']['remapPrivateView'] 

    # Extra info
    server_metrics['mem_heap_usage_bytes'] = server_status['extra_info']['heap_usage_bytes']
    server_metrics['mem_pageFaults'] = server_status['extra_info']['page_faults']

    # Global Lock
    server_metrics['lock_totalTime'] = server_status['globalLock']['totalTime']
    server_metrics['lock_queue_total'] = server_status['globalLock']['currentQueue']['total']
    server_metrics['lock_queue_readers'] = server_status['globalLock']['currentQueue']['readers']
    server_metrics['lock_queue_writers'] = server_status['globalLock']['currentQueue']['writers']
    server_metrics['lock_clients_total'] = server_status['globalLock']['activeClients']['total']
    server_metrics['lock_clients_readers'] = server_status['globalLock']['activeClients']['readers']
    server_metrics['lock_clients_writers'] = server_status['globalLock']['activeClients']['writers']

    # Index counters
    if Gem::Version.new(mongo_version) < Gem::Version.new('3.0.0')
      if server_status['indexCounters']['btree'].nil?
        server_metrics['indexes.missRatio'] = sprintf('%.5f', server_status['indexCounters']['missRatio']).to_s
        server_metrics['indexes.hits'] = server_status['indexCounters']['hits']
        server_metrics['indexes.misses'] = server_status['indexCounters']['misses']
        server_metrics['indexes_accesses'] = server_status['indexCounters']['accesses']
        server_metrics['indexes_resets'] = server_status['indexCounters']['resets']
      else
        server_metrics['indexes.missRatio'] = sprintf('%.5f', server_status['indexCounters']['btree']['missRatio']).to_s
        server_metrics['indexes.hits'] = server_status['indexCounters']['btree']['hits']
        server_metrics['indexes.misses'] = server_status['indexCounters']['btree']['misses']
        server_metrics['indexes_accesses'] = server_status['indexCounters']['btree']['accesses']
        server_metrics['indexes_resets'] = server_status['indexCounters']['btree']['resets']
      end
    end

    # Locks
    server_metrics['locks_global_acquireCount_r'] = server_status['locks']['Global']['acquireCount']['r']
    server_metrics['locks_global_acquireCount_w'] = server_status['locks']['Global']['acquireCount']['w']
    server_metrics['locks_global_acquireCount_R'] = server_status['locks']['Global']['acquireCount']['R']
    server_metrics['locks_global_acquireCount_W'] = server_status['locks']['Global']['acquireCount']['W']
    server_metrics['locks_mmapv1journal_acquireCount_r'] = server_status['locks']['MMAPV1Journal']['acquireCount']['r']
    server_metrics['locks_mmapv1journal_acquireCount_w'] = server_status['locks']['MMAPV1Journal']['acquireCount']['w']
    server_metrics['locks_mmapv1journal_acquireCount_R'] = server_status['locks']['MMAPV1Journal']['acquireCount']['R']
    server_metrics['locks_mmapv1journal_acquireWaitCount_R'] = server_status['locks']['MMAPV1Journal']['acquireWaitCount']['R']
    server_metrics['locks_mmapv1journal_timeAcquiringMicros_R'] = server_status['locks']['MMAPV1Journal']['timeAcquiringMicros']['R']
    server_metrics['locks_database_acquireCount_r'] = server_status['locks']['Database']['acquireCount']['r']
    server_metrics['locks_database_acquireCount_w'] = server_status['locks']['Database']['acquireCount']['w']
    server_metrics['locks_database_acquireCount_R'] = server_status['locks']['Database']['acquireCount']['R']
    server_metrics['locks_database_acquireCount_W'] = server_status['locks']['Database']['acquireCount']['W']
    server_metrics['locks_collection_acquireCount_R'] = server_status['locks']['Collection']['acquireCount']['R']
    server_metrics['locks_metadata_acquireCount_W'] = server_status['locks']['Metadata']['acquireCount']['W']
    server_metrics['locks_oplog_acquireCount_w'] = server_status['locks']['oplog']['acquireCount']['w']
    server_metrics['locks_oplog_acquireCount_R'] = server_status['locks']['oplog']['acquireCount']['R']

    # Network
    server_metrics['network_bytesIn'] = server_status['network']['bytesIn']
    server_metrics['network_bytesOut'] = server_status['network']['bytesOut']
    server_metrics['network_numRequests'] = server_status['network']['numRequests']

    # Opcounters
    server_metrics['opcounters_insert'] = server_status['opcounters']['insert']
    server_metrics['opcounters_query'] = server_status['opcounters']['query']
    server_metrics['opcounters_update'] = server_status['opcounters']['update']
    server_metrics['opcounters_delete'] = server_status['opcounters']['delete']
    server_metrics['opcounters_getmore'] = server_status['opcounters']['getmore']
    server_metrics['opcounters_command'] = server_status['opcounters']['command']

    # Opcounters Replication
    server_metrics['opcountersRepl_insert'] = server_status['opcountersRepl']['insert']
    server_metrics['opcountersRepl_query'] = server_status['opcountersRepl']['query']
    server_metrics['opcountersRepl_update'] = server_status['opcountersRepl']['update']
    server_metrics['opcountersRepl_delete'] = server_status['opcountersRepl']['delete']
    server_metrics['opcountersRepl_getmore'] = server_status['opcountersRepl']['getmore']
    server_metrics['opcountersRepl_command'] = server_status['opcountersRepl']['command']

    # Record stats
    output server_status['*']
    #server_metrics['recordStats_accessesNotInMemory'] = server_status['recordStats']['accessesNotInMemory']
    #server_metrics['recordStats_pageFaultExceptionsThrown'] = server_status['recordStats']['pageFaultExceptionsThrown']
    #server_metrics['recordStats_admin_accessesNotInMemory'] = server_status['recordStats']['admin']['accessesNotInMemory']
    #server_metrics['recordStats_admin_pageFaultExceptionsThrown'] = server_status['recordStats']['admin']['pageFaultExceptionsThrown']
    #server_metrics['recordStats_dashboard_accessesNotInMemory'] = server_status['recordStats']['dashboard']['accessesNotInMemory']
    #server_metrics['recordStats_dashboard_pageFaultExceptionsThrown'] = server_status['recordStats']['dashboard']['pageFaultExceptionsThrown']
    #server_metrics['recordStats_functional_accessesNotInMemory'] = server_status['recordStats']['functional']['accessesNotInMemory']
    #server_metrics['recordStats_functional_pageFaultExceptionsThrown'] = server_status['recordStats']['functional']['pageFaultExceptionsThrown']
    #server_metrics['recordStats_local_accessesNotInMemory'] = server_status['recordStats']['local']['accessesNotInMemory']
    #server_metrics['recordStats_local_pageFaultExceptionsThrown'] = server_status['recordStats']['local']['pageFaultExceptionsThrown']

    # Memory
    server_metrics['mem_residentMb'] = server_status['mem']['resident']
    server_metrics['mem_virtualMb'] = server_status['mem']['virtual']
    server_metrics['mem_mapped'] = server_status['mem']['mapped']
    server_metrics['mem_mappedWithJournal'] = server_status['mem']['mappedWithJournal']

    # Metrics
    server_metrics['metrics_cursor_timedOut'] = server_status['metrics']['cursor']['timedOut']
    server_metrics['metrics_cursor_open_noTimeout'] = server_status['metrics']['cursor']['open']['noTimeout']
    server_metrics['metrics_cursor_open_pinned'] = server_status['metrics']['cursor']['open']['pinned']
    server_metrics['metrics_cursor_open_total'] = server_status['metrics']['cursor']['open']['total']
    server_metrics['metrics_document_deleted'] = server_status['metrics']['document']['deleted']
    server_metrics['metrics_document_inserted'] = server_status['metrics']['document']['inserted']
    server_metrics['metrics_document_returned'] = server_status['metrics']['document']['returned']
    server_metrics['metrics_document_updated'] = server_status['metrics']['document']['updated']
    server_metrics['metrics_getLastError_wtime_num'] = server_status['metrics']['getLastError']['wtime']['num']
    server_metrics['metrics_getLastError_wtime_totalMillis'] = server_status['metrics']['getLastError']['wtime']['totalMillis']
    server_metrics['metrics_getLastError_wtimeouts'] = server_status['metrics']['getLastError']['wtimeouts']
    server_metrics['metrics_operation_fastmod'] = server_status['metrics']['operation']['fastmod']
    server_metrics['metrics_operation_idhack'] = server_status['metrics']['operation']['idhack']
    server_metrics['metrics_operation_scanAndOrder'] = server_status['metrics']['operation']['scanAndOrder']
    server_metrics['metrics_queryExecutor_scanned'] = server_status['metrics']['queryExecutor']['scanned']
    server_metrics['metrics_queryExecutor_scannedObjects'] = server_status['metrics']['queryExecutor']['scannedObjects']
    server_metrics['metrics_record_moves'] = server_status['metrics']['record']['moves']
    server_metrics['metrics_repl_apply_batches_num'] = server_status['metrics']['repl']['apply']['batches']['num']
    server_metrics['metrics_repl_apply_batches_totalMillis'] = server_status['metrics']['repl']['apply']['batches']['totalMillis']
    server_metrics['metrics_repl_apply_ops'] = server_status['metrics']['repl']['apply']['ops']
    server_metrics['metrics_repl_buffer_count'] = server_status['metrics']['repl']['buffer']['count']
    server_metrics['metrics_repl_buffer_maxSizeBytes'] = server_status['metrics']['repl']['buffer']['maxSizeBytes']
    server_metrics['metrics_repl_buffer_sizeBytes'] = server_status['metrics']['repl']['buffer']['sizeBytes']
    server_metrics['metrics_repl_network_bytes'] = server_status['metrics']['repl']['network']['bytes']
    server_metrics['metrics_repl_network_getmores_num'] = server_status['metrics']['repl']['network']['getmores']['num']
    server_metrics['metrics_repl_network_getmores_totalMillis'] = server_status['metrics']['repl']['network']['getmores']['totalMillis']
    server_metrics['metrics_repl_network_ops'] = server_status['metrics']['repl']['network']['ops']
    server_metrics['metrics_repl_network_readersCreated'] = server_status['metrics']['repl']['network']['readersCreated']
    server_metrics['metrics_repl_preload_docs_num'] = server_status['metrics']['repl']['preload']['docs']['num']
    server_metrics['metrics_repl_preload_docs_totalMillis'] = server_status['metrics']['repl']['preload']['docs']['totalMillis']
    server_metrics['metrics_repl_preload_indexes_num'] = server_status['metrics']['repl']['preload']['indexes']['num']
    server_metrics['metrics_repl_preload_indexes_totalMillis'] = server_status['metrics']['repl']['preload']['indexes']['totalMillis']
    server_metrics['metrics_storage_freelist_search_bucketExhauseted'] = server_status['metrics']['storage']['freelist']['search']['bucketExhausted']
    server_metrics['metrics_storage_freelist_search_requests'] = server_status['metrics']['storage']['freelist']['search']['requests']
    server_metrics['metrics_storage_freelist_search_scanned'] = server_status['metrics']['storage']['freelist']['search']['scanned']
    server_metrics['metrics_ttl_deletedDocuments'] = server_status['metrics']['ttl']['deletedDocuments']
    server_metrics['metrics_ttl_passes'] = server_status['metrics']['ttl']['passes']

    server_metrics
  end
end
