require 'mongo'
require_relative '../../spec_helper.rb'
require_relative '../../../lib/sensu-plugins-mongodb/metrics.rb'

include Mongo

describe 'SensuPluginsMongoDB::Metrics' do
  before do
    Mongo::Logger.logger.level = Logger::FATAL
    @config = {
      host: 'localhost',
      port: 27_017,
      user: 'admin',
      password: 'admin',
      debug: true
    }

    # Mock mongo client and db.
    @client = {}
    @db = {}
    allow(@client).to receive(:db).and_return(@db)
    allow(@client).to receive(:database).and_return(@db)
    allow(@client).to receive(:database_names).and_return(['admin'])
    allow(@client).to receive(:use).and_return(@client)
    allow(@db).to receive(:authenticate).and_return(@db)
    allow(@db).to receive(:name).and_return('admin')

    if Gem.loaded_specs['mongo'].version < Gem::Version.new('2.0.0')
      allow(MongoClient).to receive(:new).and_return(@client)
    else
      allow(Mongo::Client).to receive(:new).and_return(@client)
    end
  end

  describe 'mongodb 2.6.11' do
    before do
      allow(@db).to receive(:command).with('isMaster' => 1).and_return(
        fixture_db_response('master_2.6.11.json')
      )
      allow(@db).to receive(:command).with('serverStatus' => 1).and_return(
        fixture_db_response('status_2.6.11.json')
      )
      allow(@db).to receive(:command).with('replSetGetStatus' => 1).and_return(
        fixture_db_response('replicaset_status_2.6.11.json')
      )
      allow(@db).to receive(:command).with(dbstats: 1).and_return(
        fixture_db_response('stats_2.6.11.json')
      )
    end

    it 'checks for master' do
      metrics = SensuPluginsMongoDB::Metrics.new(@config)
      metrics.connect_mongo_db('admin')
      expect(metrics.master?).to be true
    end

    it 'get status' do
      metrics = SensuPluginsMongoDB::Metrics.new(@config)
      metrics.connect_mongo_db('admin')
      result = metrics.server_status
      expect(result['version']).to eq '2.6.11'
    end

    it 'get metrics' do
      metrics = SensuPluginsMongoDB::Metrics.new(@config)
      metrics.connect_mongo_db('admin')
      result = metrics.server_metrics
      expect(result).to eq(
        {
        'asserts.errors' => 0,
        'asserts.regular' => 0,
        'asserts.rollovers' => 0,
        'asserts.user' => 0,
        'asserts.warnings' => 0,
        'backgroundFlushing.average_ms' => 2.7058823529411766,
        'backgroundFlushing.flushes' => 68,
        'backgroundFlushing.last_ms' => 3,
        'backgroundFlushing.total_ms' => 184,
        'connections.available' => 52_427,
        'connections.current' => 1,
        'connections.totalCreated' => 37,
        'cursors.open.noTimeout' => 0,
        'cursors.open.pinned' => 0,
        'cursors.open.total' => 0,
        'cursors.timedOut' => 0,
        'databaseSizes.admin.collections' => 4,
        'databaseSizes.admin.objects' => 11,
        'databaseSizes.admin.avgObjSize' => 106.18181818181819,
        'databaseSizes.admin.dataSize' => 1168,
        'databaseSizes.admin.storageSize' => 286_72,
        'databaseSizes.admin.numExtents' => 4,
        'databaseSizes.admin.indexes' => 3,
        'databaseSizes.admin.indexSize' => 245_280,
        'databaseSizes.admin.fileSize' => 671_088_64,
        'databaseSizes.admin.nsSizeMB' => 16,
        'indexes.accesses' => 2,
        'indexes.hits' => 2,
        'indexes.missRatio' => '0.00000',
        'indexes.misses' => 0,
        'indexes.resets' => 0,
        'journal.commits' => 30,
        'journal.commitsInWriteLock' => 0,
        'journal.compression' => 0,
        'journal.timeMs.dt' => 3_066,
        'journal.timeMs.prepLogBuffer' => 0,
        'journal.timeMs.remapPrivateView' => 0,
        'journal.timeMs.writeToDataFiles' => 0,
        'journal.timeMs.writeToJournal' => 0,
        'journal.writeToDataFilesMB' => 0,
        'journaled_MB' => 0,
        'lock.clients_readers' => 0,
        'lock.clients_total' => 0,
        'lock.clients_writers' => 0,
        'lock.queue_readers' => 0,
        'lock.queue_total' => 0,
        'lock.queue_writers' => 0,
        'lock.totalTime' => 4_127_130_000,
        'mem.heap_usage_bytes' => 62_525_976.0,
        'mem.mapped' => 80,
        'mem.mappedWithJournal' => 160,
        'mem.pageFaults' => 236,
        'mem.residentMb' => 43,
        'mem.virtualMb' => 343,
        'metrics.document.deleted' => 0,
        'metrics.document.inserted' => 1,
        'metrics.document.returned' => 0,
        'metrics.document.updated' => 0,
        'metrics.getLastError.wtime_num' => 0,
        'metrics.getLastError.wtime_totalMillis' => 0,
        'metrics.getLastError.wtimeouts' => 0,
        'metrics.operation.fastmod' => 0,
        'metrics.operation.idhack' => 0,
        'metrics.operation.scanAndOrder' => 0,
        'metrics.queryExecutor.scanned' => 0,
        'metrics.queryExecutor.scannedObjects' => 0,
        'metrics.record.moves' => 0,
        'metrics.repl.apply.batches_num' => 0,
        'metrics.repl.apply.batches_totalMillis' => 0,
        'metrics.repl.apply.ops' => 0,
        'metrics.repl.buffer.count' => 0,
        'metrics.repl.buffer.maxSizeBytes' => 268_435_456,
        'metrics.repl.buffer.sizeBytes' => 0,
        'metrics.repl.network.bytes' => 0,
        'metrics.repl.network.getmores_num' => 0,
        'metrics.repl.network.getmores_totalMillis' => 0,
        'metrics.repl.network.ops' => 0,
        'metrics.repl.network.readersCreated' => 0,
        'metrics.repl.preload.docs_num' => 0,
        'metrics.repl.preload.docs_totalMillis' => 0,
        'metrics.repl.preload.indexes_num' => 0,
        'metrics.repl.preload.indexes_totalMillis' => 0,
        'metrics.replicaset.state' => 1,
        'metrics.storage.freelist.search_bucketExhauseted' => 0,
        'metrics.storage.freelist.search_requests' => 6,
        'metrics.storage.freelist.search_scanned' => 11,
        'metrics.ttl.deletedDocuments' => 0,
        'metrics.ttl.passes' => 68,
        'network.bytesIn' => 3_375,
        'network.bytesOut' => 56_884,
        'network.numRequests' => 53,
        'opcounters.command' => 55,
        'opcounters.delete' => 0,
        'opcounters.getmore' => 0,
        'opcounters.insert' => 1,
        'opcounters.query' => 137,
        'opcounters.update' => 0,
        'opcountersRepl.command' => 0,
        'opcountersRepl.delete' => 0,
        'opcountersRepl.getmore' => 0,
        'opcountersRepl.insert' => 0,
        'opcountersRepl.query' => 0,
        'opcountersRepl.update' => 0
      })
    end
  end

  describe 'mongodb 3.2.9' do
    before do
      allow(@db).to receive(:command).with('isMaster' => 1).and_return(
        fixture_db_response('master_3.2.9.json')
      )
      allow(@db).to receive(:command).with('serverStatus' => 1).and_return(
        fixture_db_response('status_3.2.9.json')
      )
      allow(@db).to receive(:command).with('replSetGetStatus' => 1).and_return(
        fixture_db_response('replicaset_status_3.2.9.json')
      )
      allow(@db).to receive(:command).with(dbstats: 1).and_return(
        fixture_db_response('stats_3.2.9.json')
      )
    end

    it 'checks for master' do
      metrics = SensuPluginsMongoDB::Metrics.new(@config)
      metrics.connect_mongo_db('admin')
      expect(metrics.master?).to be true
    end

    it 'get status' do
      metrics = SensuPluginsMongoDB::Metrics.new(@config)
      metrics.connect_mongo_db('admin')
      result = metrics.server_status
      expect(result['version']).to eq '3.2.9'
    end

    it 'get metrics' do
      metrics = SensuPluginsMongoDB::Metrics.new(@config)
      metrics.connect_mongo_db('admin')
      result = metrics.server_metrics
      expect(result).to eq(
        {
          "asserts.warnings" => 0, 
          "asserts.errors" => 0, 
          "asserts.regular" => 0, 
          "asserts.user" => 0, 
          "asserts.rollovers" => 0, 
          "connections.current" => 2, 
          "connections.available" => 838858, 
          "connections.totalCreated" => 30, 
          "cursors.timedOut" => 0, 
          "cursors.open.noTimeout" => 0, 
          "cursors.open.pinned" => 0, 
          "cursors.open.total" => 0, 

          "databaseSizes.admin.avgObjSize" => 106.18181818181819,
          "databaseSizes.admin.collections" => 4,
          "databaseSizes.admin.dataSize" => 1168,
          "databaseSizes.admin.fileSize" => 67108864,
          "databaseSizes.admin.indexSize" => 245_280,
          "databaseSizes.admin.indexes" => 3,
          "databaseSizes.admin.nsSizeMB" => 16,
          "databaseSizes.admin.numExtents" => 4,
          "databaseSizes.admin.objects" => 11,
          "databaseSizes.admin.storageSize" => 28672,

          "mem.pageFaults"=>0, 
          "mem.heap_size_bytes"=>64520192, 
          "lock.totalTime"=>1112002000, 
          "lock.queue_total"=>0, 
          "lock.queue_readers"=>0, 
          "lock.queue_writers"=>0, 
          "lock.clients_total"=>9, 
          "lock.clients_readers"=>0, 
          "lock.clients_writers"=>0, 
          "locks.Collection.acquireCount_r"=>304, 
          "locks.Global.acquireCount_r"=>653, 
          "locks.Global.acquireCount_w"=>653, 
          "locks.Global.acquireCount_W"=>653, 
          "locks.Database.acquireCount_r"=>313, 
          "locks.Database.acquireCount_R"=>313, 
          "locks.Database.acquireCount_W"=>313, 
          "network.bytesIn"=>7932, 
          "network.bytesOut"=>182742, 
          "network.numRequests"=>66, 
          "opcounters.insert"=>0, 
          "opcounters.query"=>1, 
          "opcounters.update"=>0, 
          "opcounters.delete"=>0, 
          "opcounters.getmore"=>0, 
          "opcounters.command"=>67, 
          "opcountersRepl.insert"=>0, 
          "opcountersRepl.query"=>0, 
          "opcountersRepl.update"=>0, 
          "opcountersRepl.delete"=>0, 
          "opcountersRepl.getmore"=>0, 
          "opcountersRepl.command"=>0, 
          "mem.residentMb"=>50, 
          "mem.virtualMb"=>244, 
          "mem.mapped"=>0, 
          "mem.mappedWithJournal"=>0, 
          "mem.current_allocated_bytes"=>60183928, 
          "wiredTiger.data_handle.session_dhandles_swept"=>0, 
          "wiredTiger.data_handle.connection_sweeps"=>111, 
          "wiredTiger.data_handle.connection_sweep_dhandles_removed_from_hash_list"=>72, 
          "wiredTiger.data_handle.connection_data_handles_currently_active"=>6, 
          "wiredTiger.data_handle.connection_sweep_dhandles_closed"=>0, 
          "wiredTiger.data_handle.session_sweep_attempts"=>33, 
          "wiredTiger.data_handle.connection_sweep_candidate_became_referenced"=>0, 
          "wiredTiger.data_handle.connection_sweep_time-of-death_sets"=>72, 
          "wiredTiger.reconciliation.fast-path_pages_deleted"=>0, 
          "wiredTiger.reconciliation.split_objects_currently_awaiting_free"=>0, 
          "wiredTiger.reconciliation.split_bytes_currently_awaiting_free"=>0, 
          "wiredTiger.reconciliation.pages_deleted"=>0, 
          "wiredTiger.reconciliation.page_reconciliation_calls_for_eviction"=>0, 
          "wiredTiger.reconciliation.page_reconciliation_calls"=>12, 
          "wiredTiger.cache.unmodified_pages_evicted"=>0, 
          "wiredTiger.cache.eviction_server_evicting_pages"=>0, 
          "wiredTiger.cache.tracked_dirty_pages_in_the_cache"=>0, 
          "wiredTiger.cache.eviction_calls_to_get_a_page_found_queue_empty_after_locking"=>0, 
          "wiredTiger.cache.internal_pages_split_during_eviction"=>0, 
          "wiredTiger.cache.page_split_during_eviction_deepened_the_tree"=>0, 
          "wiredTiger.cache.leaf_pages_split_during_eviction"=>0, 
          "wiredTiger.cache.pages_walked_for_eviction"=>0, 
          "wiredTiger.cache.percentage_overhead"=>8, 
          "wiredTiger.cache.pages_evicted_by_application_threads"=>0, 
          "wiredTiger.cache.tracked_dirty_bytes_in_the_cache"=>0, 
          "wiredTiger.cache.maximum_page_size_at_eviction"=>0, 
          "wiredTiger.cache.failed_eviction_of_pages_that_exceeded_the_in-memory_maximum"=>0, 

          "wiredTiger.cache.pages_evicted_because_they_exceeded_the_in-memory_maximum"=>0, 
          "wiredTiger.cache.tracked_bytes_belonging_to_leaf_pages_in_the_cache"=>31212, 
          "wiredTiger.cache.eviction_server_candidate_queue_empty_when_topping_up"=>0, 
          "wiredTiger.cache.bytes_written_from_cache"=>19144, 

          "wiredTiger.cache.eviction_server_slept,_because_we_did_not_make_progress_with_eviction"=>0, 
          "wiredTiger.cache.pages_queued_for_urgent_eviction"=>0, 
          "wiredTiger.cache.eviction_currently_operating_in_aggressive_mode"=>0, 
          "wiredTiger.cache.tracked_bytes_belonging_to_internal_pages_in_the_cache"=>13631, 
          "wiredTiger.cache.bytes_currently_in_the_cache"=>44843, 
          "wiredTiger.cache.pages_selected_for_eviction_unable_to_be_evicted"=>0, 
          "wiredTiger.cache.hazard_pointer_maximum_array_length"=>0, 
          "wiredTiger.cache.lookaside_table_remove_calls"=>0, 
          "wiredTiger.cache.in-memory_page_passed_criteria_to_be_split"=>0, 
          "wiredTiger.cache.checkpoint_blocked_page_eviction"=>0, 
          "wiredTiger.cache.eviction_calls_to_get_a_page_found_queue_empty"=>0, 
          "wiredTiger.cache.pages_written_from_cache"=>12, 
          "wiredTiger.cache.eviction_calls_to_get_a_page"=>0, 
          "wiredTiger.cache.modified_pages_evicted_by_application_threads"=>0, 
          "wiredTiger.cache.pages_seen_by_eviction_walk"=>0, 
          "wiredTiger.cache.eviction_worker_thread_evicting_pages"=>0, 
          "wiredTiger.cache.bytes_read_into_cache"=>7541, 
          "wiredTiger.cache.page_written_requiring_lookaside_records"=>0, 
          "wiredTiger.cache.hazard_pointer_blocked_page_eviction"=>0, 
          "wiredTiger.cache.lookaside_table_insert_calls"=>0, 
          "wiredTiger.cache.pages_read_into_cache"=>10, 
          "wiredTiger.cache.pages_written_requiring_in-memory_restoration"=>0, 
          "wiredTiger.cache.pages_evicted_because_they_had_chains_of_deleted_items"=>0, 
          "wiredTiger.cache.files_with_new_eviction_walks_started"=>0, 
          "wiredTiger.cache.pages_queued_for_eviction"=>0, 
          "wiredTiger.cache.pages_requested_from_the_cache"=>244, 
          "wiredTiger.cache.pages_read_into_cache_requiring_lookaside_entries"=>0, 
          "wiredTiger.cache.eviction_server_candidate_queue_not_empty_when_topping_up"=>0, 
          "wiredTiger.cache.files_with_active_eviction_walks"=>0, 
          "wiredTiger.cache.hazard_pointer_check_entries_walked"=>0, 
          "wiredTiger.cache.in-memory_page_splits"=>0, 
          "wiredTiger.cache.internal_pages_evicted"=>0, 

          "wiredTiger.cache.maximum_bytes_configured"=>1073741824.0, 
          "wiredTiger.cache.pages_currently_held_in_the_cache"=>11, 
          "wiredTiger.cache.modified_pages_evicted"=>0, 
          "wiredTiger.cache.eviction_server_unable_to_reach_eviction_goal"=>0, 
          "wiredTiger.cache.hazard_pointer_check_calls"=>0, 
          "wiredTiger.log.log_sync_dir_operations"=>1, 
          "wiredTiger.log.log_sync_dir_time_duration_(usecs)"=>16, 
          "wiredTiger.log.log_write_operations"=>11, 
          "wiredTiger.log.log_server_thread_advances_write_LSN"=>2, 
          "wiredTiger.log.consolidated_slot_join_races"=>0, 
          "wiredTiger.log.maximum_log_file_size"=>104857600, 
          "wiredTiger.log.records_processed_by_log_scan"=>10, 
          "wiredTiger.log.total_log_buffer_size"=>33554432, 
          "wiredTiger.log.log_records_too_small_to_compress"=>6, 
          "wiredTiger.log.log_force_write_operations_skipped"=>12166, 
          "wiredTiger.log.log_scan_operations"=>3, 
          "wiredTiger.log.pre-allocated_log_files_used"=>0, 
          "wiredTiger.log.pre-allocated_log_files_not_ready_and_missed"=>1, 
          "wiredTiger.log.total_size_of_compressed_records"=>3183, 
          "wiredTiger.log.pre-allocated_log_files_prepared"=>2, 
          "wiredTiger.log.log_sync_time_duration_(usecs)"=>14238, 
          "wiredTiger.log.total_in-memory_size_of_compressed_records"=>4749, 
          "wiredTiger.log.yields_waiting_for_previous_log_file_close"=>0, 
          "wiredTiger.log.log_records_not_compressed"=>1, 
          "wiredTiger.log.log_force_write_operations"=>12168, 
          "wiredTiger.log.consolidated_slot_unbuffered_writes"=>0, 
          "wiredTiger.log.written_slots_coalesced"=>0, 
          "wiredTiger.log.log_records_compressed"=>4, 
          "wiredTiger.log.number_of_pre-allocated_log_files_to_create"=>2, 
          "wiredTiger.log.log_bytes_written"=>4736, 
          "wiredTiger.log.busy_returns_attempting_to_switch_slots"=>0, 
          "wiredTiger.log.consolidated_slot_joins"=>11, 
          "wiredTiger.log.log_files_manually_zero-filled"=>0, 
          "wiredTiger.log.log_bytes_of_payload_data"=>3497, 
          "wiredTiger.log.log_flush_operations"=>11023, 
          "wiredTiger.log.log_sync_operations"=>7, 
          "wiredTiger.log.log_scan_records_requiring_two_reads"=>4, 
          "wiredTiger.log.logging_bytes_consolidated"=>4352, 
          "wiredTiger.log.log_server_thread_write_LSN_walk_skipped"=>2078, 
          "wiredTiger.log.consolidated_slot_join_transitions"=>7, 
          "wiredTiger.log.log_release_advances_write_LSN"=>5, 
          "wiredTiger.log.consolidated_slot_closures"=>7, 
          "wiredTiger.LSM.sleep_for_LSM_merge_throttle"=>0, 
          "wiredTiger.LSM.application_work_units_currently_queued"=>0, 
          "wiredTiger.LSM.rows_merged_in_an_LSM_tree"=>0, 
          "wiredTiger.LSM.switch_work_units_currently_queued"=>0, 
          "wiredTiger.LSM.merge_work_units_currently_queued"=>0, 
          "wiredTiger.LSM.tree_maintenance_operations_discarded"=>0, 
          "wiredTiger.LSM.sleep_for_LSM_checkpoint_throttle"=>0, 
          "wiredTiger.LSM.tree_maintenance_operations_executed"=>0, 
          "wiredTiger.LSM.tree_maintenance_operations_scheduled"=>0, 
          "wiredTiger.LSM.tree_queue_hit_maximum"=>0, 
          "wiredTiger.transaction.number_of_named_snapshots_dropped"=>0, 
          "wiredTiger.transaction.transaction_checkpoint_currently_running"=>0, 
          "wiredTiger.transaction.transaction_begins"=>41, 
          "wiredTiger.transaction.transaction_fsync_calls_for_checkpoint_after_allocating_the_transaction_ID"=>19, 
          "wiredTiger.transaction.transactions_committed"=>4, 
          "wiredTiger.transaction.transaction_checkpoint_most_recent_time_(msecs)"=>6, 
          "wiredTiger.transaction.transaction_checkpoints"=>19, 
          "wiredTiger.transaction.transaction_range_of_IDs_currently_pinned_by_a_checkpoint"=>0, 
          "wiredTiger.transaction.transaction_sync_calls"=>0, 
          "wiredTiger.transaction.transaction_fsync_duration_for_checkpoint_after_allocating_the_transaction_ID_(usecs)"=>21003, 
          "wiredTiger.transaction.transaction_checkpoint_max_time_(msecs)"=>8, 
          "wiredTiger.transaction.number_of_named_snapshots_created"=>0, 
          "wiredTiger.transaction.transaction_checkpoint_min_time_(msecs)"=>6, 
          "wiredTiger.transaction.transaction_checkpoint_total_time_(msecs)"=>28, 
          "wiredTiger.transaction.transaction_checkpoint_generation"=>19, 
          "wiredTiger.transaction.transaction_failures_due_to_cache_overflow"=>0, 
          "wiredTiger.transaction.transaction_range_of_IDs_currently_pinned_by_named_snapshots"=>0, 
          "wiredTiger.transaction.transactions_rolled_back"=>37, 
          "wiredTiger.transaction.transaction_range_of_IDs_currently_pinned"=>0, 
          "wiredTiger.cursor.cursor_restarted_searches"=>0, 
          "wiredTiger.cursor.cursor_prev_calls"=>3, 
          "wiredTiger.cursor.cursor_insert_calls"=>12, 
          "wiredTiger.cursor.cursor_reset_calls"=>220, 
          "wiredTiger.cursor.cursor_update_calls"=>0, 
          "wiredTiger.cursor.cursor_search_near_calls"=>1, 
          "wiredTiger.cursor.cursor_search_calls"=>209, 
          "wiredTiger.cursor.cursor_next_calls"=>28, 
          "wiredTiger.cursor.cursor_create_calls"=>29, 
          "wiredTiger.cursor.truncate_calls"=>0, 
          "wiredTiger.cursor.cursor_remove_calls"=>1, 
          "wiredTiger.connection.total_read_I/Os"=>876, 
          "wiredTiger.connection.memory_re-allocations"=>4577, 
          "wiredTiger.connection.pthread_mutex_shared_lock_write-lock_calls"=>1296, 
          "wiredTiger.connection.auto_adjusting_condition_resets"=>9, 
          "wiredTiger.connection.pthread_mutex_condition_wait_calls"=>14531, 
          "wiredTiger.connection.memory_frees"=>19113, 
          "wiredTiger.connection.pthread_mutex_shared_lock_read-lock_calls"=>2574, 
          "wiredTiger.connection.total_fsync_I/Os"=>190, 
          "wiredTiger.connection.files_currently_open"=>9, 
          "wiredTiger.connection.memory_allocations"=>19700, 
          "wiredTiger.connection.auto_adjusting_condition_wait_calls"=>3372, 
          "wiredTiger.connection.total_write_I/Os"=>38, 
          "wiredTiger.session.open_cursor_count"=>20,  
          "wiredTiger.session.open_session_count"=>16,  
          "wiredTiger.block_manager.bytes_read"=>69632, 
          "wiredTiger.block_manager.blocks_read"=>16, 
          "wiredTiger.block_manager.blocks_pre-loaded"=>5, 
          "wiredTiger.block_manager.bytes_written"=>110592, 
          "wiredTiger.block_manager.mapped_bytes_read"=>0, 
          "wiredTiger.block_manager.blocks_written"=>24, 
          "wiredTiger.block_manager.mapped_blocks_read"=>0, 
          "wiredTiger.thread_yield.page_acquire_busy_blocked"=>0, 
          "wiredTiger.thread_yield.page_acquire_read_blocked"=>0, 
          "wiredTiger.thread_yield.page_acquire_locked_blocked"=>0, 
          "wiredTiger.thread_yield.page_acquire_eviction_blocked"=>0, 
          "wiredTiger.thread_yield.page_acquire_time_sleeping_(usecs)"=>0, 
          "wiredTiger.async.total_insert_calls"=>0, 
          "wiredTiger.async.total_remove_calls"=>0, 
          "wiredTiger.async.number_of_operation_slots_viewed_for_allocation"=>0, 
          "wiredTiger.async.total_allocations"=>0, 
          "wiredTiger.async.current_work_queue_length"=>0, 
          "wiredTiger.async.number_of_flush_calls"=>0, 
          "wiredTiger.async.maximum_work_queue_length"=>0, 
          "wiredTiger.async.total_compact_calls"=>0, 
          "wiredTiger.async.total_update_calls"=>0, 
          "wiredTiger.async.number_of_allocation_state_races"=>0, 
          "wiredTiger.async.number_of_times_operation_allocation_failed"=>0, 
          "wiredTiger.async.number_of_times_worker_found_no_work"=>0, 
          "wiredTiger.async.total_search_calls"=>0, 
          "wiredTiger.concurrentTransactions.write.out"=>0, 
          "wiredTiger.concurrentTransactions.write.available"=>128, 
          "wiredTiger.concurrentTransactions.write.totalTickets"=>128, 
          "wiredTiger.concurrentTransactions.read.out"=>0, 
          "wiredTiger.concurrentTransactions.read.available"=>128, 
          "wiredTiger.concurrentTransactions.read.totalTickets"=>128, 
          "wiredTiger.thread_state.active_filesystem_write_calls"=>0, 
          "wiredTiger.thread_state.active_filesystem_read_calls"=>0, 
          "wiredTiger.thread_state.active_filesystem_fsync_calls"=>0, 
          "metrics.document.deleted"=>0, 
          "metrics.document.inserted"=>0, 
          "metrics.document.returned"=>0, 
          "metrics.document.updated"=>0, 
          "metrics.getLastError.wtime_num"=>0, 
          "metrics.getLastError.wtime_totalMillis"=>0, 
          "metrics.getLastError.wtimeouts"=>0, 
          "metrics.operation.fastmod"=>0, 
          "metrics.operation.idhack"=>0, 
          "metrics.operation.scanAndOrder"=>0, 
          "metrics.queryExecutor.scanned"=>0, 
          "metrics.queryExecutor.scannedObjects"=>0, 
          "metrics.record.moves"=>0, 
          "metrics.repl.apply.batches_num"=>0, 
          "metrics.repl.apply.batches_totalMillis"=>0, 
          "metrics.repl.apply.ops"=>0, 
          "metrics.repl.buffer.count"=>0, 
          "metrics.repl.buffer.maxSizeBytes"=>268435456, 
          "metrics.repl.buffer.sizeBytes"=>0, 
          "metrics.repl.network.bytes"=>0, 
          "metrics.repl.network.getmores_num"=>0, 
          "metrics.repl.network.getmores_totalMillis"=>0, 
          "metrics.repl.network.ops"=>0, 
          "metrics.repl.network.readersCreated"=>0, 
          "metrics.repl.preload.docs_num"=>0, 
          "metrics.repl.preload.docs_totalMillis"=>0, 
          "metrics.repl.preload.indexes_num"=>0, 
          "metrics.repl.preload.indexes_totalMillis"=>0, 
          'metrics.replicaset.state' => 1,
          "metrics.storage.freelist.search_bucketExhauseted"=>0, 
          "metrics.storage.freelist.search_requests"=>0, 
          "metrics.storage.freelist.search_scanned"=>0, 
          "metrics.ttl.deletedDocuments"=>0, 
          "metrics.ttl.passes"=>18
        }
      )
    end
  end
end
