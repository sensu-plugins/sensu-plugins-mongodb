require 'mongo'
include Mongo

module SensuPluginsMongoDB
  class Metrics
    # Initializes a Metrics collector.
    #
    # @param config [Mesh]
    #   the config object parsed from the command line.
    #   Must include: :host, :port, :user, :password, :debug
    def initialize(config)
      @config = config
      @connected = false
      @db = nil
      @mongo_client = nil
    end

    # Connects to a mongo database.
    #
    # @param db_name [String] the name of the db to connect to.
    def connect_mongo_db(db_name)
      if @connected
        raise 'Already connected to a database'
      end

      db_user = @config[:user]
      db_password = @config[:password]

      if Gem.loaded_specs['mongo'].version < Gem::Version.new('2.0.0')
        @mongo_client = get_mongo_client(db_name)
        @db = @mongo_client.db(db_name)
        @db.authenticate(db_user, db_password) unless db_user.nil?
      else
        @mongo_client = get_mongo_client(db_name)
        @db = @mongo_client.database
      end
    end

    # Fetches a document from the mongo db.
    #
    # @param command [Mesh] the command to search documents with.
    # @return [Mesh, nil] the first document or nil.
    def get_mongo_doc(command)
      unless @connected
        raise 'Cannot fetch documents before connecting.'
      end
      unless @db
        raise 'Cannot fetch documents without a db.'
      end

      rs = @db.command(command)
      unless rs.successful?
        return nil
      end
      rs.documents[0]
    end

    # Checks if the connected node is the master node.
    #
    # @return [true, false] true when the node is a master node.
    def master?
      result = false
      begin
        @is_master = get_mongo_doc('isMaster' => 1)
        unless @is_master.nil?
          result = @is_master['ok'] == 1 && @is_master['ismaster']
        end
      rescue StandardError => e
        if @config[:debug]
          puts 'Error checking isMaster: ' + e.message
          puts e.backtrace.inspect
        end
      end
      result
    end

    # Fetches the status of the server (which includes the metrics).
    #
    # @return [Mash, nil] the document showing the server status or nil.
    def server_status
      status = get_mongo_doc('serverStatus' => 1)
      return nil if status.nil? || status['ok'] != 1
      return status
    rescue StandardError => e
      if @debug
        puts 'Error checking serverStatus: ' + e.message
        puts e.backtrace.inspect
      end
    end

    # Fetches the replicaset status of the server (which includes the metrics).
    #
    # @return [Mash, nil] the document showing the replicaset status or nil.
    def replicaset_status
      status = get_mongo_doc('replSetGetStatus' => 1)
      return nil if status.nil?
      return status
    rescue StandardError => e
      if @debug
        puts 'Error checking replSetGetStatus: ' + e.message
        puts e.backtrace.inspect
      end
    end

    def wiretiger_metrics(wiredtiger, server_metrics)
      # wiredtiger = server_status['wiredTiger']
      # data_handle Metrics
      wiredtiger.each do |key1, value1|
        next unless value1.is_a? Hash
        wiredtiger[key1].each do |key2, value2|
          if value2.is_a? Hash
            wiredtiger[key1][key2].each do |key3, value3|
              server_metrics['wiredTiger.' + key1.gsub(/(,|\s|-|\()+/, '_').tr(')', '') + '.' +
                key2.gsub(/(,|\s|-|\()+/, '_').tr(')', '') + '.' + key3.gsub(/(,|\s|-|\()+/, '_').tr(')', '')] = value3
            end
          else
            server_metrics['wiredTiger.' + key1.gsub(/(,|\s|-|\()+/, '_').tr(')', '') +
              '.' + key2.gsub(/(,|\s|-|\()+/, '_').tr(')', '')] = value2
          end
        end
      end
      server_metrics
    end

    # Fetches metrics for the server we are connected to.
    #
    # @return [Mash] the metrics for the server.
    # rubocop:disable Metrics/AbcSize
    def server_metrics
      server_status = self.server_status
      replicaset_status = self.replicaset_status
      server_metrics = {}
      # Handle versions like "2.6.11-pre" etc
      mongo_version = server_status['version'].gsub(/[^0-9\.]/i, '')

      server_metrics['lock.ratio'] = sprintf('%.5f', server_status['globalLock']['ratio']).to_s unless server_status['globalLock']['ratio'].nil?

      # Asserts
      asserts = server_status['asserts']
      server_metrics['asserts.warnings'] = asserts['warning']
      server_metrics['asserts.errors'] = asserts['msg']
      server_metrics['asserts.regular'] = asserts['regular']
      server_metrics['asserts.user'] = asserts['user']
      server_metrics['asserts.rollovers'] = asserts['rollovers']

      # Background flushing
      if server_status.key?('backgroundFlushing')
        bg_flushing = server_status['backgroundFlushing']
        server_metrics['backgroundFlushing.flushes'] = bg_flushing['flushes']
        server_metrics['backgroundFlushing.total_ms'] = bg_flushing['total_ms']
        server_metrics['backgroundFlushing.average_ms'] = bg_flushing['average_ms']
        server_metrics['backgroundFlushing.last_ms'] = bg_flushing['last_ms']
      end

      # Connections
      connections = server_status['connections']
      server_metrics['connections.current'] = connections['current']
      server_metrics['connections.available'] = connections['available']
      server_metrics['connections.totalCreated'] = connections['totalCreated']

      # Cursors (use new metrics.cursor from mongo 2.6+)
      if Gem::Version.new(mongo_version) < Gem::Version.new('2.6.0')
        cursors = server_status['cursors']
        server_metrics['clientCursors.size'] = cursors['clientCursors_size']
        server_metrics['cursors.timedOut'] = cursors['timedOut']

        # Metric names match the version 2.6+ format for standardization!
        server_metrics['cursors.open.NoTimeout'] = cursors['totalNoTimeout']
        server_metrics['cursors.open.pinned'] = cursors['pinned']
        server_metrics['cursors.open.total'] = cursors['totalOpen']
      else
        cursors = server_status['metrics']['cursor']
        server_metrics['cursors.timedOut'] = cursors['timedOut']
        # clientCursors.size has been replaced by cursors.open.total

        open = cursors['open']
        server_metrics['cursors.open.noTimeout'] = open['noTimeout']
        server_metrics['cursors.open.pinned'] = open['pinned']
        server_metrics['cursors.open.total'] = open['total']

        unless Gem::Version.new(mongo_version) < Gem::Version.new('3.0.0')
          server_metrics['cursors.open.multiTarget'] = open['multiTarget']
          server_metrics['cursors.open.singleTarget'] = open['singleTarget']
        end
      end

      # Database Sizes
      @mongo_client.database_names.each do |name|
        @mongo_client = @mongo_client.use(name)
        db = @mongo_client.database
        result = db.command(dbstats: 1).documents.first
        server_metrics["databaseSizes.#{name}.collections"] = result['collections']
        server_metrics["databaseSizes.#{name}.objects"] = result['objects']
        server_metrics["databaseSizes.#{name}.avgObjSize"] = result['avgObjSize']
        server_metrics["databaseSizes.#{name}.dataSize"] = result['dataSize']
        server_metrics["databaseSizes.#{name}.storageSize"] = result['storageSize']
        server_metrics["databaseSizes.#{name}.numExtents"] = result['numExtents']
        server_metrics["databaseSizes.#{name}.indexes"] = result['indexes']
        server_metrics["databaseSizes.#{name}.indexSize"] = result['indexSize']
        server_metrics["databaseSizes.#{name}.fileSize"] = result['fileSize']
        server_metrics["databaseSizes.#{name}.nsSizeMB"] = result['nsSizeMB']
      end
      # Reset back to previous database
      @mongo_client = @mongo_client.use(@db.name)

      # Journaling (durability)
      if server_status.key?('dur')
        dur = server_status['dur']
        server_metrics['journal.commits'] = dur['commits']
        server_metrics['journaled_MB'] = dur['journaledMB']
        server_metrics['journal.timeMs.writeToDataFiles'] = dur['timeMs']['writeToDataFiles']
        server_metrics['journal.writeToDataFilesMB'] = dur['writeToDataFilesMB']
        server_metrics['journal.compression'] = dur['compression']
        server_metrics['journal.commitsInWriteLock'] = dur['commitsInWriteLock']
        server_metrics['journal.timeMs.dt'] = dur['timeMs']['dt']
        server_metrics['journal.timeMs.prepLogBuffer'] = dur['timeMs']['prepLogBuffer']
        server_metrics['journal.timeMs.writeToJournal'] = dur['timeMs']['writeToJournal']
        server_metrics['journal.timeMs.remapPrivateView'] = dur['timeMs']['remapPrivateView']
      end

      # Extra info
      extra_info = server_status['extra_info']
      server_metrics['mem.pageFaults'] = extra_info['page_faults']
      server_metrics['mem.heap_size_bytes'] = extra_info['heap_size']
      # Global Lock
      global_lock = server_status['globalLock']
      server_metrics['lock.totalTime'] = global_lock['totalTime']
      server_metrics['lock.queue_total'] = global_lock['currentQueue']['total']
      server_metrics['lock.queue_readers'] = global_lock['currentQueue']['readers']
      server_metrics['lock.queue_writers'] = global_lock['currentQueue']['writers']
      server_metrics['lock.clients_total'] = global_lock['activeClients']['total']
      server_metrics['lock.clients_readers'] = global_lock['activeClients']['readers']
      server_metrics['lock.clients_writers'] = global_lock['activeClients']['writers']

      # Index counters
      if Gem::Version.new(mongo_version) < Gem::Version.new('3.0.0')
        index_counters = server_status['indexCounters']
        index_counters = server_status['indexCounters']['btree'] unless server_status['indexCounters']['btree'].nil?
        server_metrics['indexes.missRatio'] = sprintf('%.5f', index_counters['missRatio']).to_s
        server_metrics['indexes.hits'] = index_counters['hits']
        server_metrics['indexes.misses'] = index_counters['misses']
        server_metrics['indexes.accesses'] = index_counters['accesses']
        server_metrics['indexes.resets'] = index_counters['resets']
      end

      # Locks (from mongo 3.0+ only)
      unless Gem::Version.new(mongo_version) < Gem::Version.new('3.0.0')
        locks = server_status['locks']
        lock_namespaces = %w(
          Collection Global Database Metadata
          MMAPV1Journal oplog
        )
        lock_dimentions = %w(
          acquireCount acquireWaitCount
          timeAcquiringMicros deadlockCount
        )

        lock_namespaces.each do |ns|
          lock_dimentions.each do |dm|
            next unless locks.key?(ns) && locks[ns].key?(dm)
            lock = locks[ns][dm]
            server_metrics["locks.#{ns}.#{dm}_r"] = lock['r'] if lock.key?('r')
            server_metrics["locks.#{ns}.#{dm}_w"] = lock['r'] if lock.key?('w')
            server_metrics["locks.#{ns}.#{dm}_R"] = lock['r'] if lock.key?('R')
            server_metrics["locks.#{ns}.#{dm}_W"] = lock['r'] if lock.key?('W')
          end
        end
      end

      # Network
      network = server_status['network']
      server_metrics['network.bytesIn'] = network['bytesIn']
      server_metrics['network.bytesOut'] = network['bytesOut']
      server_metrics['network.numRequests'] = network['numRequests']

      # OpLatencies
      if server_status.key?('opLatencies')
        oplatencies = server_status['opLatencies']
        server_metrics['oplatencies.read.latency'] = oplatencies['reads']['latency']
        server_metrics['oplatencies.read.operations'] = oplatencies['reads']['ops']
        server_metrics['oplatencies.write.latency'] = oplatencies['writes']['latency']
        server_metrics['oplatencies.write.operations'] = oplatencies['writes']['ops']
        server_metrics['oplatencies.command.latency'] = oplatencies['commands']['latency']
        server_metrics['oplatencies.command.operations'] = oplatencies['commands']['ops']
      end

      # Opcounters
      opcounters = server_status['opcounters']
      opcounters.each do |key, value|
        server_metrics['opcounters.' + key] = value
      end

      # Opcounters Replication
      opcounters_repl = server_status['opcountersRepl']
      opcounters_repl.each do |key, value|
        server_metrics['opcountersRepl.' + key] = value
      end

      # Memory
      mem = server_status['mem']
      server_metrics['mem.residentMb'] = mem['resident']
      server_metrics['mem.virtualMb'] = mem['virtual']
      server_metrics['mem.mapped'] = mem['mapped']
      server_metrics['mem.mappedWithJournal'] = mem['mappedWithJournal']

      # Malloc
      if server_status.key?('wiredTiger')
        malloc = server_status['tcmalloc']
        server_metrics['mem.heap_size_bytes'] = malloc['generic']['heap_size']
        server_metrics['mem.current_allocated_bytes'] = malloc['generic']['current_allocated_bytes']
      end
      # WiredTiger specific Metrics
      if server_status.key?('wiredTiger')
        wiredtiger = server_status['wiredTiger']
        server_metrics = wiretiger_metrics(wiredtiger, server_metrics)
      end

      # Metrics (documents)
      document = server_status['metrics']['document']
      server_metrics['metrics.document.deleted'] = document['deleted']
      server_metrics['metrics.document.inserted'] = document['inserted']
      server_metrics['metrics.document.returned'] = document['returned']
      server_metrics['metrics.document.updated'] = document['updated']

      # Metrics (getLastError)
      get_last_error = server_status['metrics']['getLastError']
      server_metrics['metrics.getLastError.wtime_num'] = get_last_error['wtime']['num']
      server_metrics['metrics.getLastError.wtime_totalMillis'] = get_last_error['wtime']['totalMillis']
      server_metrics['metrics.getLastError.wtimeouts'] = get_last_error['wtimeouts']

      # Metrics (operation)
      operation = server_status['metrics']['operation']
      server_metrics['metrics.operation.fastmod'] = operation['fastmod']
      server_metrics['metrics.operation.idhack'] = operation['idhack']
      server_metrics['metrics.operation.scanAndOrder'] = operation['scanAndOrder']

      # Metrics (operation)
      query_executor = server_status['metrics']['queryExecutor']
      server_metrics['metrics.queryExecutor.scanned'] = query_executor['scanned']
      server_metrics['metrics.queryExecutor.scannedObjects'] = query_executor['scannedObjects']
      server_metrics['metrics.record.moves'] = server_status['metrics']['record']['moves']

      # Metrics (repl)
      repl = server_status['metrics']['repl']
      server_metrics['metrics.repl.apply.batches_num'] = repl['apply']['batches']['num']
      server_metrics['metrics.repl.apply.batches_totalMillis'] = repl['apply']['batches']['totalMillis']
      server_metrics['metrics.repl.apply.ops'] = repl['apply']['ops']
      server_metrics['metrics.repl.buffer.count'] = repl['buffer']['count']
      server_metrics['metrics.repl.buffer.maxSizeBytes'] = repl['buffer']['maxSizeBytes']
      server_metrics['metrics.repl.buffer.sizeBytes'] = repl['buffer']['sizeBytes']
      server_metrics['metrics.repl.network.bytes'] = repl['network']['bytes']
      server_metrics['metrics.repl.network.getmores_num'] = repl['network']['getmores']['num']
      server_metrics['metrics.repl.network.getmores_totalMillis'] = repl['network']['getmores']['totalMillis']
      server_metrics['metrics.repl.network.ops'] = repl['network']['ops']
      server_metrics['metrics.repl.network.readersCreated'] = repl['network']['readersCreated']
      server_metrics['metrics.repl.preload.docs_num'] = repl['preload']['docs']['num']
      server_metrics['metrics.repl.preload.docs_totalMillis'] = repl['preload']['docs']['totalMillis']
      server_metrics['metrics.repl.preload.indexes_num'] = repl['preload']['indexes']['num']
      server_metrics['metrics.repl.preload.indexes_totalMillis'] = repl['preload']['indexes']['totalMillis']

      # Metrics (replicaset status)
      # MongoDB will fail if not running with --replSet, hence the check for nil
      unless replicaset_status.nil?
        server_metrics['metrics.replicaset.state'] = replicaset_status['myState']
      end

      # Metrics (storage)
      if Gem::Version.new(mongo_version) >= Gem::Version.new('2.6.0')
        freelist = server_status['metrics']['storage']['freelist']
        server_metrics['metrics.storage.freelist.search_bucketExhauseted'] = freelist['search']['bucketExhausted']
        server_metrics['metrics.storage.freelist.search_requests'] = freelist['search']['requests']
        server_metrics['metrics.storage.freelist.search_scanned'] = freelist['search']['scanned']
      end

      # Metrics (ttl)
      ttl = server_status['metrics']['ttl']
      server_metrics['metrics.ttl.deletedDocuments'] = ttl['deletedDocuments']
      server_metrics['metrics.ttl.passes'] = ttl['passes']

      # Return metrics map.
      # MongoDB returns occasional nils and floats as {"floatApprox": x}.
      # Clean up the results once here to avoid per-metric logic.
      clean_metrics = {}
      server_metrics.each do |k, v|
        next if v.nil?
        if v.is_a?(Hash) && v.key?('floatApprox')
          v = v['floatApprox']
        end
        clean_metrics[k] = v
      end
      clean_metrics
    end

    private

    def get_mongo_client(db_name)
      @connected = true
      host = @config[:host]
      port = @config[:port]
      db_user = @config[:user]
      db_password = @config[:password]
      ssl = @config[:ssl]
      ssl_cert = @config[:ssl_cert]
      ssl_key = @config[:ssl_key]
      ssl_ca_cert = @config[:ssl_ca_cert]
      ssl_verify = @config[:ssl_verify]

      if Gem.loaded_specs['mongo'].version < Gem::Version.new('2.0.0')
        MongoClient.new(host, port)
      else
        address_str = "#{host}:#{port}"
        client_opts = {}
        client_opts[:database] = db_name
        unless db_user.nil?
          client_opts[:user] = db_user
          client_opts[:password] = db_password
        end
        if ssl
          client_opts[:ssl] = true
          client_opts[:ssl_cert] = ssl_cert
          client_opts[:ssl_key] = ssl_key
          client_opts[:ssl_ca_cert] = ssl_ca_cert
          client_opts[:ssl_verify] = ssl_verify
        end
        Mongo::Client.new([address_str], client_opts)
      end
    end
  end
end
