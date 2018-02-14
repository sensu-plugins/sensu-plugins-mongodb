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
      oplatencies = server_status['opLatencies']
      server_metrics['oplatencies.read.latency'] = oplatencies['reads']['latency']
      server_metrics['oplatencies.read.operations'] = oplatencies['reads']['ops']
      server_metrics['oplatencies.write.latency'] = oplatencies['writes']['latency']
      server_metrics['oplatencies.write.operations'] = oplatencies['writes']['ops']
      server_metrics['oplatencies.command.latency'] = oplatencies['commands']['latency']
      server_metrics['oplatencies.command.operations'] = oplatencies['commands']['ops']

      # Opcounters
      opcounters = server_status['opcounters']
      server_metrics['opcounters.insert'] = opcounters['insert']
      server_metrics['opcounters.query'] = opcounters['query']
      server_metrics['opcounters.update'] = opcounters['update']
      server_metrics['opcounters.delete'] = opcounters['delete']
      server_metrics['opcounters.getmore'] = opcounters['getmore']
      server_metrics['opcounters.command'] = opcounters['command']

      # Opcounters Replication
      opcounters_repl = server_status['opcountersRepl']
      server_metrics['opcountersRepl.insert'] = opcounters_repl['insert']
      server_metrics['opcountersRepl.query'] = opcounters_repl['query']
      server_metrics['opcountersRepl.update'] = opcounters_repl['update']
      server_metrics['opcountersRepl.delete'] = opcounters_repl['delete']
      server_metrics['opcountersRepl.getmore'] = opcounters_repl['getmore']
      server_metrics['opcountersRepl.command'] = opcounters_repl['command']

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
            wiredTiger = server_status['wiredTiger']
            # data_handle Metrics
            data_handle = wiredTiger['data-handle']
            server_metrics['wiredTiger.data_handle.session_dhandles_swept'] = data_handle['session dhandles swept']
            server_metrics['wiredTiger.data_handle.connection_sweeps'] = data_handle['connection sweeps']
            server_metrics['wiredTiger.data_handle.connection_sweep_dhandles_removed_from_hash_list'] = data_handle['connection sweep dhandles removed from hash list']
            server_metrics['wiredTiger.data_handle.connection_data_handles_currently_active'] = data_handle['connection data handles currently active']
            server_metrics['wiredTiger.data_handle.connection_sweep_dhandles_closed'] = data_handle['connection sweep dhandles closed']
            server_metrics['wiredTiger.data_handle.session_sweep_attempts'] = data_handle['session sweep attempts']
            server_metrics['wiredTiger.data_handle.connection_sweep_candidate_became_referenced'] = data_handle['connection sweep candidate became referenced']
            server_metrics['wiredTiger.data_handle.connection_sweep_time-of-death_sets'] = data_handle['connection sweep time-of-death sets']


            # reconciliation Metrics
            reconciliation = wiredTiger['reconciliation']
            server_metrics['wiredTiger.reconciliation.fast-path_pages_deleted'] = reconciliation['fast-path pages deleted']
            server_metrics['wiredTiger.reconciliation.split_objects_currently_awaiting_free'] = reconciliation['split objects currently awaiting free']
            server_metrics['wiredTiger.reconciliation.split_bytes_currently_awaiting_free'] = reconciliation['split bytes currently awaiting free']
            server_metrics['wiredTiger.reconciliation.pages_deleted'] = reconciliation['pages deleted']
            server_metrics['wiredTiger.reconciliation.page_reconciliation_calls_for_eviction'] = reconciliation['page reconciliation calls for eviction']
            server_metrics['wiredTiger.reconciliation.page_reconciliation_calls'] = reconciliation['page reconciliation calls']


            # cache Metrics
            cache = wiredTiger['cache']
            server_metrics['wiredTiger.cache.unmodified_pages_evicted'] = cache['unmodified pages evicted']
            server_metrics['wiredTiger.cache.eviction_server_evicting_pages'] = cache['eviction server evicting pages']
            server_metrics['wiredTiger.cache.tracked_dirty_pages_in_the_cache'] = cache['tracked dirty pages in the cache']
            server_metrics['wiredTiger.cache.overflow_values_cached_in_memory'] = cache['overflow values cached in memory']
            server_metrics['wiredTiger.cache.eviction_calls_to_get_a_page_found_queue_empty_after_locking'] = cache['eviction calls to get a page found queue empty after locking']
            server_metrics['wiredTiger.cache.internal_pages_split_during_eviction'] = cache['internal pages split during eviction']
            server_metrics['wiredTiger.cache.application_threads_page_write_from_cache_to_disk_time_(usecs)'] = cache['application threads page write from cache to disk time (usecs)']
            server_metrics['wiredTiger.cache.page_split_during_eviction_deepened_the_tree'] = cache['page split during eviction deepened the tree']
            server_metrics['wiredTiger.cache.leaf_pages_split_during_eviction'] = cache['leaf pages split during eviction']
            server_metrics['wiredTiger.cache.pages_walked_for_eviction'] = cache['pages walked for eviction']
            server_metrics['wiredTiger.cache.percentage_overhead'] = cache['percentage overhead']
            server_metrics['wiredTiger.cache.pages_evicted_by_application_threads'] = cache['pages evicted by application threads']
            server_metrics['wiredTiger.cache.tracked_dirty_bytes_in_the_cache'] = cache['tracked dirty bytes in the cache']
            server_metrics['wiredTiger.cache.maximum_page_size_at_eviction'] = cache['maximum page size at eviction']
            server_metrics['wiredTiger.cache.failed_eviction_of_pages_that_exceeded_the_in-memory_maximum'] = cache['failed eviction of pages that exceeded the in-memory maximum']
            server_metrics['wiredTiger.cache.application_threads_page_write_from_cache_to_disk_count'] = cache['application threads page write from cache to disk count']
            server_metrics['wiredTiger.cache.eviction_worker_thread_stable_number'] = cache['eviction worker thread stable number']
            server_metrics['wiredTiger.cache.pages_evicted_because_they_exceeded_the_in-memory_maximum'] = cache['pages evicted because they exceeded the in-memory maximum']
            server_metrics['wiredTiger.cache.tracked_bytes_belonging_to_leaf_pages_in_the_cache'] = cache['tracked bytes belonging to leaf pages in the cache']
            server_metrics['wiredTiger.cache.eviction_server_candidate_queue_empty_when_topping_up'] = cache['eviction server candidate queue empty when topping up']
            server_metrics['wiredTiger.cache.bytes_written_from_cache'] = cache['bytes written from cache']
            server_metrics['wiredTiger.cache.force_re-tuning_of_eviction_workers_once_in_a_while'] = cache['force re-tuning of eviction workers once in a while']
            server_metrics['wiredTiger.cache.eviction_empty_score'] = cache['eviction empty score']
            server_metrics['wiredTiger.cache.eviction_server_slept,_because_we_did_not_make_progress_with_eviction'] = cache['eviction server slept, because we did not make progress with eviction']
            server_metrics['wiredTiger.cache.pages_queued_for_urgent_eviction'] = cache['pages queued for urgent eviction']
            server_metrics['wiredTiger.cache.eviction_walks_abandoned'] = cache['eviction walks abandoned']
            server_metrics['wiredTiger.cache.eviction_currently_operating_in_aggressive_mode'] = cache['eviction currently operating in aggressive mode']
            server_metrics['wiredTiger.cache.application_threads_page_read_from_disk_to_cache_count'] = cache['application threads page read from disk to cache count']
            server_metrics['wiredTiger.cache.tracked_bytes_belonging_to_internal_pages_in_the_cache'] = cache['tracked bytes belonging to internal pages in the cache']
            server_metrics['wiredTiger.cache.bytes_currently_in_the_cache'] = cache['bytes currently in the cache']
            server_metrics['wiredTiger.cache.pages_selected_for_eviction_unable_to_be_evicted'] = cache['pages selected for eviction unable to be evicted']
            server_metrics['wiredTiger.cache.hazard_pointer_maximum_array_length'] = cache['hazard pointer maximum array length']
            server_metrics['wiredTiger.cache.lookaside_table_remove_calls'] = cache['lookaside table remove calls']
            server_metrics['wiredTiger.cache.in-memory_page_passed_criteria_to_be_split'] = cache['in-memory page passed criteria to be split']
            server_metrics['wiredTiger.cache.eviction_state'] = cache['eviction state']
            server_metrics['wiredTiger.cache.checkpoint_blocked_page_eviction'] = cache['checkpoint blocked page eviction']
            server_metrics['wiredTiger.cache.pages_queued_for_urgent_eviction_during_walk'] = cache['pages queued for urgent eviction during walk']
            server_metrics['wiredTiger.cache.eviction_calls_to_get_a_page_found_queue_empty'] = cache['eviction calls to get a page found queue empty']
            server_metrics['wiredTiger.cache.application_threads_page_read_from_disk_to_cache_time_(usecs)'] = cache['application threads page read from disk to cache time (usecs)']
            server_metrics['wiredTiger.cache.pages_written_from_cache'] = cache['pages written from cache']
            server_metrics['wiredTiger.cache.eviction_calls_to_get_a_page'] = cache['eviction calls to get a page']
            server_metrics['wiredTiger.cache.modified_pages_evicted_by_application_threads'] = cache['modified pages evicted by application threads']
            server_metrics['wiredTiger.cache.pages_seen_by_eviction_walk'] = cache['pages seen by eviction walk']
            server_metrics['wiredTiger.cache.eviction_worker_thread_evicting_pages'] = cache['eviction worker thread evicting pages']
            server_metrics['wiredTiger.cache.bytes_read_into_cache'] = cache['bytes read into cache']
            server_metrics['wiredTiger.cache.page_written_requiring_lookaside_records'] = cache['page written requiring lookaside records']
            server_metrics['wiredTiger.cache.hazard_pointer_blocked_page_eviction'] = cache['hazard pointer blocked page eviction']
            server_metrics['wiredTiger.cache.lookaside_table_insert_calls'] = cache['lookaside table insert calls']
            server_metrics['wiredTiger.cache.bytes_not_belonging_to_page_images_in_the_cache'] = cache['bytes not belonging to page images in the cache']
            server_metrics['wiredTiger.cache.pages_read_into_cache'] = cache['pages read into cache']
            server_metrics['wiredTiger.cache.pages_written_requiring_in-memory_restoration'] = cache['pages written requiring in-memory restoration']
            server_metrics['wiredTiger.cache.pages_evicted_because_they_had_chains_of_deleted_items'] = cache['pages evicted because they had chains of deleted items']
            server_metrics['wiredTiger.cache.files_with_new_eviction_walks_started'] = cache['files with new eviction walks started']
            server_metrics['wiredTiger.cache.pages_queued_for_eviction'] = cache['pages queued for eviction']
            server_metrics['wiredTiger.cache.eviction_worker_thread_removed'] = cache['eviction worker thread removed']
            server_metrics['wiredTiger.cache.eviction_worker_thread_active'] = cache['eviction worker thread active']
            server_metrics['wiredTiger.cache.pages_requested_from_the_cache'] = cache['pages requested from the cache']
            server_metrics['wiredTiger.cache.pages_read_into_cache_requiring_lookaside_entries'] = cache['pages read into cache requiring lookaside entries']
            server_metrics['wiredTiger.cache.eviction_server_candidate_queue_not_empty_when_topping_up'] = cache['eviction server candidate queue not empty when topping up']
            server_metrics['wiredTiger.cache.files_with_active_eviction_walks'] = cache['files with active eviction walks']
            server_metrics['wiredTiger.cache.hazard_pointer_check_entries_walked'] = cache['hazard pointer check entries walked']
            server_metrics['wiredTiger.cache.in-memory_page_splits'] = cache['in-memory page splits']
            server_metrics['wiredTiger.cache.internal_pages_evicted'] = cache['internal pages evicted']
            server_metrics['wiredTiger.cache.eviction_worker_thread_created'] = cache['eviction worker thread created']
            server_metrics['wiredTiger.cache.overflow_pages_read_into_cache'] = cache['overflow pages read into cache']
            server_metrics['wiredTiger.cache.maximum_bytes_configured'] = cache['maximum bytes configured']
            server_metrics['wiredTiger.cache.pages_currently_held_in_the_cache'] = cache['pages currently held in the cache']
            server_metrics['wiredTiger.cache.modified_pages_evicted'] = cache['modified pages evicted']
            server_metrics['wiredTiger.cache.eviction_server_unable_to_reach_eviction_goal'] = cache['eviction server unable to reach eviction goal']
            server_metrics['wiredTiger.cache.bytes_belonging_to_page_images_in_the_cache'] = cache['bytes belonging to page images in the cache']
            server_metrics['wiredTiger.cache.hazard_pointer_check_calls'] = cache['hazard pointer check calls']


            # log Metrics
            log = wiredTiger['log']
            server_metrics['wiredTiger.log.log_sync_dir_operations'] = log['log sync_dir operations']
            server_metrics['wiredTiger.log.log_sync_dir_time_duration_(usecs)'] = log['log sync_dir time duration (usecs)']
            server_metrics['wiredTiger.log.log_write_operations'] = log['log write operations']
            server_metrics['wiredTiger.log.log_server_thread_advances_write_LSN'] = log['log server thread advances write LSN']
            server_metrics['wiredTiger.log.consolidated_slot_join_races'] = log['consolidated slot join races']
            server_metrics['wiredTiger.log.maximum_log_file_size'] = log['maximum log file size']
            server_metrics['wiredTiger.log.records_processed_by_log_scan'] = log['records processed by log scan']
            server_metrics['wiredTiger.log.total_log_buffer_size'] = log['total log buffer size']
            server_metrics['wiredTiger.log.log_records_too_small_to_compress'] = log['log records too small to compress']
            server_metrics['wiredTiger.log.log_force_write_operations_skipped'] = log['log force write operations skipped']
            server_metrics['wiredTiger.log.log_scan_operations'] = log['log scan operations']
            server_metrics['wiredTiger.log.pre-allocated_log_files_used'] = log['pre-allocated log files used']
            server_metrics['wiredTiger.log.pre-allocated_log_files_not_ready_and_missed'] = log['pre-allocated log files not ready and missed']
            server_metrics['wiredTiger.log.total_size_of_compressed_records'] = log['total size of compressed records']
            server_metrics['wiredTiger.log.pre-allocated_log_files_prepared'] = log['pre-allocated log files prepared']
            server_metrics['wiredTiger.log.log_sync_time_duration_(usecs)'] = log['log sync time duration (usecs)']
            server_metrics['wiredTiger.log.total_in-memory_size_of_compressed_records'] = log['total in-memory size of compressed records']
            server_metrics['wiredTiger.log.yields_waiting_for_previous_log_file_close'] = log['yields waiting for previous log file close']
            server_metrics['wiredTiger.log.log_records_not_compressed'] = log['log records not compressed']
            server_metrics['wiredTiger.log.log_force_write_operations'] = log['log force write operations']
            server_metrics['wiredTiger.log.consolidated_slot_unbuffered_writes'] = log['consolidated slot unbuffered writes']
            server_metrics['wiredTiger.log.written_slots_coalesced'] = log['written slots coalesced']
            server_metrics['wiredTiger.log.consolidated_slot_join_active_slot_closed'] = log['consolidated slot join active slot closed']
            server_metrics['wiredTiger.log.log_records_compressed'] = log['log records compressed']
            server_metrics['wiredTiger.log.number_of_pre-allocated_log_files_to_create'] = log['number of pre-allocated log files to create']
            server_metrics['wiredTiger.log.log_bytes_written'] = log['log bytes written']
            server_metrics['wiredTiger.log.busy_returns_attempting_to_switch_slots'] = log['busy returns attempting to switch slots']
            server_metrics['wiredTiger.log.consolidated_slot_transitions_unable_to_find_free_slot'] = log['consolidated slot transitions unable to find free slot']
            server_metrics['wiredTiger.log.consolidated_slot_joins'] = log['consolidated slot joins']
            server_metrics['wiredTiger.log.log_files_manually_zero-filled'] = log['log files manually zero-filled']
            server_metrics['wiredTiger.log.log_bytes_of_payload_data'] = log['log bytes of payload data']
            server_metrics['wiredTiger.log.log_flush_operations'] = log['log flush operations']
            server_metrics['wiredTiger.log.log_sync_operations'] = log['log sync operations']
            server_metrics['wiredTiger.log.log_scan_records_requiring_two_reads'] = log['log scan records requiring two reads']
            server_metrics['wiredTiger.log.logging_bytes_consolidated'] = log['logging bytes consolidated']
            server_metrics['wiredTiger.log.log_server_thread_write_LSN_walk_skipped'] = log['log server thread write LSN walk skipped']
            server_metrics['wiredTiger.log.consolidated_slot_join_transitions'] = log['consolidated slot join transitions']
            server_metrics['wiredTiger.log.log_release_advances_write_LSN'] = log['log release advances write LSN']
            server_metrics['wiredTiger.log.consolidated_slot_closures'] = log['consolidated slot closures']


            # lock Metrics
            lock = wiredTiger['lock']
            server_metrics['wiredTiger.lock.schema_lock_application_thread_wait_time_(usecs)'] = lock['schema lock application thread wait time (usecs)']
            server_metrics['wiredTiger.lock.table_lock_application_thread_time_waiting_for_the_table_lock_(usecs)'] = lock['table lock application thread time waiting for the table lock (usecs)']
            server_metrics['wiredTiger.lock.checkpoint_lock_internal_thread_wait_time_(usecs)'] = lock['checkpoint lock internal thread wait time (usecs)']
            server_metrics['wiredTiger.lock.schema_lock_acquisitions'] = lock['schema lock acquisitions']
            server_metrics['wiredTiger.lock.handle-list_lock_eviction_thread_wait_time_(usecs)'] = lock['handle-list lock eviction thread wait time (usecs)']
            server_metrics['wiredTiger.lock.checkpoint_lock_acquisitions'] = lock['checkpoint lock acquisitions']
            server_metrics['wiredTiger.lock.table_lock_internal_thread_time_waiting_for_the_table_lock_(usecs)'] = lock['table lock internal thread time waiting for the table lock (usecs)']
            server_metrics['wiredTiger.lock.checkpoint_lock_application_thread_wait_time_(usecs)'] = lock['checkpoint lock application thread wait time (usecs)']
            server_metrics['wiredTiger.lock.table_lock_acquisitions'] = lock['table lock acquisitions']
            server_metrics['wiredTiger.lock.metadata_lock_application_thread_wait_time_(usecs)'] = lock['metadata lock application thread wait time (usecs)']
            server_metrics['wiredTiger.lock.schema_lock_internal_thread_wait_time_(usecs)'] = lock['schema lock internal thread wait time (usecs)']
            server_metrics['wiredTiger.lock.metadata_lock_internal_thread_wait_time_(usecs)'] = lock['metadata lock internal thread wait time (usecs)']
            server_metrics['wiredTiger.lock.metadata_lock_acquisitions'] = lock['metadata lock acquisitions']


            # LSM Metrics
            LSM = wiredTiger['LSM']
            server_metrics['wiredTiger.LSM.sleep_for_LSM_merge_throttle'] = LSM['sleep for LSM merge throttle']
            server_metrics['wiredTiger.LSM.application_work_units_currently_queued'] = LSM['application work units currently queued']
            server_metrics['wiredTiger.LSM.rows_merged_in_an_LSM_tree'] = LSM['rows merged in an LSM tree']
            server_metrics['wiredTiger.LSM.switch_work_units_currently_queued'] = LSM['switch work units currently queued']
            server_metrics['wiredTiger.LSM.merge_work_units_currently_queued'] = LSM['merge work units currently queued']
            server_metrics['wiredTiger.LSM.tree_maintenance_operations_discarded'] = LSM['tree maintenance operations discarded']
            server_metrics['wiredTiger.LSM.sleep_for_LSM_checkpoint_throttle'] = LSM['sleep for LSM checkpoint throttle']
            server_metrics['wiredTiger.LSM.tree_maintenance_operations_executed'] = LSM['tree maintenance operations executed']
            server_metrics['wiredTiger.LSM.tree_maintenance_operations_scheduled'] = LSM['tree maintenance operations scheduled']
            server_metrics['wiredTiger.LSM.tree_queue_hit_maximum'] = LSM['tree queue hit maximum']


            # transaction Metrics
            transaction = wiredTiger['transaction']
            server_metrics['wiredTiger.transaction.number_of_named_snapshots_dropped'] = transaction['number of named snapshots dropped']
            server_metrics['wiredTiger.transaction.transaction_checkpoint_currently_running'] = transaction['transaction checkpoint currently running']
            server_metrics['wiredTiger.transaction.transaction_begins'] = transaction['transaction begins']
            server_metrics['wiredTiger.transaction.transaction_fsync_calls_for_checkpoint_after_allocating_the_transaction_ID'] = transaction['transaction fsync calls for checkpoint after allocating the transaction ID']
            server_metrics['wiredTiger.transaction.transactions_committed'] = transaction['transactions committed']
            server_metrics['wiredTiger.transaction.transaction_checkpoint_most_recent_time_(msecs)'] = transaction['transaction checkpoint most recent time (msecs)']
            server_metrics['wiredTiger.transaction.transaction_checkpoints'] = transaction['transaction checkpoints']
            server_metrics['wiredTiger.transaction.transaction_range_of_IDs_currently_pinned_by_a_checkpoint'] = transaction['transaction range of IDs currently pinned by a checkpoint']
            server_metrics['wiredTiger.transaction.transaction_sync_calls'] = transaction['transaction sync calls']
            server_metrics['wiredTiger.transaction.transaction_checkpoint_scrub_dirty_target'] = transaction['transaction checkpoint scrub dirty target']
            server_metrics['wiredTiger.transaction.transaction_fsync_duration_for_checkpoint_after_allocating_the_transaction_ID_(usecs)'] = transaction['transaction fsync duration for checkpoint after allocating the transaction ID (usecs)']
            server_metrics['wiredTiger.transaction.transaction_checkpoints_skipped_because_database_was_clean'] = transaction['transaction checkpoints skipped because database was clean']
            server_metrics['wiredTiger.transaction.transaction_checkpoint_scrub_time_(msecs)'] = transaction['transaction checkpoint scrub time (msecs)']
            server_metrics['wiredTiger.transaction.transaction_checkpoint_max_time_(msecs)'] = transaction['transaction checkpoint max time (msecs)']
            server_metrics['wiredTiger.transaction.number_of_named_snapshots_created'] = transaction['number of named snapshots created']
            server_metrics['wiredTiger.transaction.transaction_checkpoint_min_time_(msecs)'] = transaction['transaction checkpoint min time (msecs)']
            server_metrics['wiredTiger.transaction.transaction_checkpoint_total_time_(msecs)'] = transaction['transaction checkpoint total time (msecs)']
            server_metrics['wiredTiger.transaction.transaction_checkpoint_generation'] = transaction['transaction checkpoint generation']
            server_metrics['wiredTiger.transaction.transaction_failures_due_to_cache_overflow'] = transaction['transaction failures due to cache overflow']
            server_metrics['wiredTiger.transaction.transaction_range_of_IDs_currently_pinned_by_named_snapshots'] = transaction['transaction range of IDs currently pinned by named snapshots']
            server_metrics['wiredTiger.transaction.transactions_rolled_back'] = transaction['transactions rolled back']
            server_metrics['wiredTiger.transaction.transaction_range_of_IDs_currently_pinned'] = transaction['transaction range of IDs currently pinned']


            # cursor Metrics
            cursor = wiredTiger['cursor']
            server_metrics['wiredTiger.cursor.cursor_restarted_searches'] = cursor['cursor restarted searches']
            server_metrics['wiredTiger.cursor.cursor_prev_calls'] = cursor['cursor prev calls']
            server_metrics['wiredTiger.cursor.cursor_insert_calls'] = cursor['cursor insert calls']
            server_metrics['wiredTiger.cursor.cursor_reset_calls'] = cursor['cursor reset calls']
            server_metrics['wiredTiger.cursor.cursor_update_calls'] = cursor['cursor update calls']
            server_metrics['wiredTiger.cursor.cursor_search_near_calls'] = cursor['cursor search near calls']
            server_metrics['wiredTiger.cursor.cursor_search_calls'] = cursor['cursor search calls']
            server_metrics['wiredTiger.cursor.cursor_next_calls'] = cursor['cursor next calls']
            server_metrics['wiredTiger.cursor.cursor_create_calls'] = cursor['cursor create calls']
            server_metrics['wiredTiger.cursor.truncate_calls'] = cursor['truncate calls']
            server_metrics['wiredTiger.cursor.cursor_remove_calls'] = cursor['cursor remove calls']


            # connection Metrics
            connection = wiredTiger['connection']
            server_metrics['wiredTiger.connection.total_read_I/Os'] = connection['total read I/Os']
            server_metrics['wiredTiger.connection.memory_re-allocations'] = connection['memory re-allocations']
            server_metrics['wiredTiger.connection.pthread_mutex_shared_lock_write-lock_calls'] = connection['pthread mutex shared lock write-lock calls']
            server_metrics['wiredTiger.connection.auto_adjusting_condition_resets'] = connection['auto adjusting condition resets']
            server_metrics['wiredTiger.connection.detected_system_time_went_backwards'] = connection['detected system time went backwards']
            server_metrics['wiredTiger.connection.pthread_mutex_condition_wait_calls'] = connection['pthread mutex condition wait calls']
            server_metrics['wiredTiger.connection.memory_frees'] = connection['memory frees']
            server_metrics['wiredTiger.connection.pthread_mutex_shared_lock_read-lock_calls'] = connection['pthread mutex shared lock read-lock calls']
            server_metrics['wiredTiger.connection.total_fsync_I/Os'] = connection['total fsync I/Os']
            server_metrics['wiredTiger.connection.files_currently_open'] = connection['files currently open']
            server_metrics['wiredTiger.connection.memory_allocations'] = connection['memory allocations']
            server_metrics['wiredTiger.connection.auto_adjusting_condition_wait_calls'] = connection['auto adjusting condition wait calls']
            server_metrics['wiredTiger.connection.total_write_I/Os'] = connection['total write I/Os']


            # session Metrics
            session = wiredTiger['session']
            server_metrics['wiredTiger.session.table_drop_successful_calls'] = session['table drop successful calls']
            server_metrics['wiredTiger.session.table_alter_unchanged_and_skipped'] = session['table alter unchanged and skipped']
            server_metrics['wiredTiger.session.table_truncate_failed_calls'] = session['table truncate failed calls']
            server_metrics['wiredTiger.session.table_compact_failed_calls'] = session['table compact failed calls']
            server_metrics['wiredTiger.session.table_salvage_successful_calls'] = session['table salvage successful calls']
            server_metrics['wiredTiger.session.open_cursor_count'] = session['open cursor count']
            server_metrics['wiredTiger.session.table_create_failed_calls'] = session['table create failed calls']
            server_metrics['wiredTiger.session.table_create_successful_calls'] = session['table create successful calls']
            server_metrics['wiredTiger.session.table_verify_successful_calls'] = session['table verify successful calls']
            server_metrics['wiredTiger.session.table_drop_failed_calls'] = session['table drop failed calls']
            server_metrics['wiredTiger.session.open_session_count'] = session['open session count']
            server_metrics['wiredTiger.session.table_verify_failed_calls'] = session['table verify failed calls']
            server_metrics['wiredTiger.session.table_rename_successful_calls'] = session['table rename successful calls']
            server_metrics['wiredTiger.session.table_rebalance_failed_calls'] = session['table rebalance failed calls']
            server_metrics['wiredTiger.session.table_alter_failed_calls'] = session['table alter failed calls']
            server_metrics['wiredTiger.session.table_rebalance_successful_calls'] = session['table rebalance successful calls']
            server_metrics['wiredTiger.session.table_salvage_failed_calls'] = session['table salvage failed calls']
            server_metrics['wiredTiger.session.table_truncate_successful_calls'] = session['table truncate successful calls']
            server_metrics['wiredTiger.session.table_alter_successful_calls'] = session['table alter successful calls']
            server_metrics['wiredTiger.session.table_compact_successful_calls'] = session['table compact successful calls']
            server_metrics['wiredTiger.session.table_rename_failed_calls'] = session['table rename failed calls']


            # block_manager Metrics
            block_manager = wiredTiger['block-manager']
            server_metrics['wiredTiger.block_manager.bytes_read'] = block_manager['bytes read']
            server_metrics['wiredTiger.block_manager.blocks_read'] = block_manager['blocks read']
            server_metrics['wiredTiger.block_manager.blocks_pre-loaded'] = block_manager['blocks pre-loaded']
            server_metrics['wiredTiger.block_manager.bytes_written'] = block_manager['bytes written']
            server_metrics['wiredTiger.block_manager.mapped_bytes_read'] = block_manager['mapped bytes read']
            server_metrics['wiredTiger.block_manager.bytes_written_for_checkpoint'] = block_manager['bytes written for checkpoint']
            server_metrics['wiredTiger.block_manager.blocks_written'] = block_manager['blocks written']
            server_metrics['wiredTiger.block_manager.mapped_blocks_read'] = block_manager['mapped blocks read']


            # thread_yield Metrics
            thread_yield = wiredTiger['thread-yield']
            server_metrics['wiredTiger.thread_yield.page_acquire_busy_blocked'] = thread_yield['page acquire busy blocked']
            server_metrics['wiredTiger.thread_yield.page_reconciliation_yielded_due_to_child_modification'] = thread_yield['page reconciliation yielded due to child modification']
            server_metrics['wiredTiger.thread_yield.data_handle_lock_yielded'] = thread_yield['data handle lock yielded']
            server_metrics['wiredTiger.thread_yield.connection_close_blocked_waiting_for_transaction_state_stabilization'] = thread_yield['connection close blocked waiting for transaction state stabilization']
            server_metrics['wiredTiger.thread_yield.connection_close_yielded_for_lsm_manager_shutdown'] = thread_yield['connection close yielded for lsm manager shutdown']
            server_metrics['wiredTiger.thread_yield.application_thread_time_evicting_(usecs)'] = thread_yield['application thread time evicting (usecs)']
            server_metrics['wiredTiger.thread_yield.reference_for_page_index_and_slot_yielded'] = thread_yield['reference for page index and slot yielded']
            server_metrics['wiredTiger.thread_yield.page_acquire_read_blocked'] = thread_yield['page acquire read blocked']
            server_metrics['wiredTiger.thread_yield.log_server_sync_yielded_for_log_write'] = thread_yield['log server sync yielded for log write']
            server_metrics['wiredTiger.thread_yield.page_acquire_locked_blocked'] = thread_yield['page acquire locked blocked']
            server_metrics['wiredTiger.thread_yield.page_delete_rollback_yielded_for_instantiation'] = thread_yield['page delete rollback yielded for instantiation']
            server_metrics['wiredTiger.thread_yield.tree_descend_one_level_yielded_for_split_page_index_update'] = thread_yield['tree descend one level yielded for split page index update']
            server_metrics['wiredTiger.thread_yield.page_acquire_eviction_blocked'] = thread_yield['page acquire eviction blocked']
            server_metrics['wiredTiger.thread_yield.application_thread_time_waiting_for_cache_(usecs)'] = thread_yield['application thread time waiting for cache (usecs)']
            server_metrics['wiredTiger.thread_yield.page_acquire_time_sleeping_(usecs)'] = thread_yield['page acquire time sleeping (usecs)']


            # async Metrics
            async = wiredTiger['async']
            server_metrics['wiredTiger.async.total_insert_calls'] = async['total insert calls']
            server_metrics['wiredTiger.async.total_remove_calls'] = async['total remove calls']
            server_metrics['wiredTiger.async.number_of_operation_slots_viewed_for_allocation'] = async['number of operation slots viewed for allocation']
            server_metrics['wiredTiger.async.total_allocations'] = async['total allocations']
            server_metrics['wiredTiger.async.current_work_queue_length'] = async['current work queue length']
            server_metrics['wiredTiger.async.number_of_flush_calls'] = async['number of flush calls']
            server_metrics['wiredTiger.async.maximum_work_queue_length'] = async['maximum work queue length']
            server_metrics['wiredTiger.async.total_compact_calls'] = async['total compact calls']
            server_metrics['wiredTiger.async.total_update_calls'] = async['total update calls']
            server_metrics['wiredTiger.async.number_of_allocation_state_races'] = async['number of allocation state races']
            server_metrics['wiredTiger.async.number_of_times_operation_allocation_failed'] = async['number of times operation allocation failed']
            server_metrics['wiredTiger.async.number_of_times_worker_found_no_work'] = async['number of times worker found no work']
            server_metrics['wiredTiger.async.total_search_calls'] = async['total search calls']


            # concurrentTransactions Metrics
            concurrentTransactions = wiredTiger['concurrentTransactions']
            server_metrics['wiredTiger.concurrentTransactions.write.out'] = concurrentTransactions['write']['out']
            server_metrics['wiredTiger.concurrentTransactions.write.available'] = concurrentTransactions['write']['available']
            server_metrics['wiredTiger.concurrentTransactions.write.totalTickets'] = concurrentTransactions['write']['totalTickets']

            server_metrics['wiredTiger.concurrentTransactions.read.out'] = concurrentTransactions['read']['out']
            server_metrics['wiredTiger.concurrentTransactions.read.available'] = concurrentTransactions['read']['available']
            server_metrics['wiredTiger.concurrentTransactions.read.totalTickets'] = concurrentTransactions['read']['totalTickets']

            # thread-state Metrics
            thread_state = wiredTiger['thread-state']
            server_metrics['wiredTiger.thread_state.active_filesystem_write_calls'] = thread_state['active filesystem write calls']
            server_metrics['wiredTiger.thread_state.active_filesystem_read_calls'] = thread_state['active filesystem read calls']
            server_metrics['wiredTiger.thread_state.active_filesystem_fsync_calls'] = thread_state['active filesystem fsync calls']

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
