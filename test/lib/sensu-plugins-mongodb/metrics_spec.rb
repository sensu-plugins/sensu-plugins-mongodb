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
        'databaseSizes.admin.dataSize' => 1168.0,
        'databaseSizes.admin.storageSize' => 286_72.0,
        'databaseSizes.admin.numExtents' => 4,
        'databaseSizes.admin.indexes' => 3,
        'databaseSizes.admin.indexSize' => 245_28.0,
        'databaseSizes.admin.fileSize' => 671_088_64.0,
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
        'mem.heap_usage_bytes' => 62_525_976,
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
      )
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
        'asserts.errors' => 0,
        'asserts.regular' => 0,
        'asserts.rollovers' => 0,
        'asserts.user' => 0,
        'asserts.warnings' => 0,
        'connections.available' => 52_427,
        'connections.current' => 1,
        'connections.totalCreated' => 76,
        'cursors.open.noTimeout' => 0,
        'cursors.open.pinned' => 0,
        'cursors.open.total' => 0,
        'cursors.timedOut' => 0,
        'databaseSizes.admin.collections' => 4,
        'databaseSizes.admin.objects' => 11,
        'databaseSizes.admin.avgObjSize' => 106.18181818181819,
        'databaseSizes.admin.dataSize' => 1168.0,
        'databaseSizes.admin.storageSize' => 286_72.0,
        'databaseSizes.admin.numExtents' => 4,
        'databaseSizes.admin.indexes' => 3,
        'databaseSizes.admin.indexSize' => 245_28.0,
        'databaseSizes.admin.fileSize' => 671_088_64.0,
        'databaseSizes.admin.nsSizeMB' => 16,
        'lock.clients_readers' => 0,
        'lock.clients_total' => 8,
        'lock.clients_writers' => 0,
        'lock.queue_readers' => 0,
        'lock.queue_total' => 0,
        'lock.queue_writers' => 0,
        'lock.totalTime' => 4_261_830_000,
        'locks.Collection.acquireCount_r' => 1_142,
        'locks.Database.acquireCount_W' => 1_142,
        'locks.Database.acquireCount_r' => 1_142,
        'locks.Global.acquireCount_W' => 2_290,
        'locks.Global.acquireCount_r' => 2_290,
        'locks.Global.acquireCount_w' => 2_290,
        'mem.heap_usage_bytes' => 60_214_264,
        'mem.mapped' => 0,
        'mem.mappedWithJournal' => 0,
        'mem.pageFaults' => 256,
        'mem.residentMb' => 49,
        'mem.virtualMb' => 245,
        'metrics.document.deleted' => 0,
        'metrics.document.inserted' => 0,
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
        'metrics.storage.freelist.search_requests' => 0,
        'metrics.storage.freelist.search_scanned' => 0,
        'metrics.ttl.deletedDocuments' => 0,
        'metrics.ttl.passes' => 71,
        'metrics.wired_tiger.block_manager.blocks_read' => 1,
        'metrics.wired_tiger.block_manager.blocks_written' => 19,
        'metrics.wired_tiger.block_manager.mapped_blocks_read' => 0,
        'metrics.wired_tiger.cache.eviction_server_evicting_pages' => 0,
        'metrics.wired_tiger.cache.bytes_currently_in_the_cache' => 15_825,
        'metrics.wired_tiger.cache.bytes_read_into_cache' => 0,
        'metrics.wired_tiger.cache.bytes_written_from_cache' => 12_762,
        'metrics.wired_tiger.cache.maximum_bytes_configured' => 8_589_934_592,
        'metrics.wired_tiger.cache.modified_pages_evicted' => 0,
        'metrics.wired_tiger.cache.pages_currently_held_in_the_cache' => 11,
        'metrics.wired_tiger.cache.tracked_dirty_bytes_in_the_cache' => 0,
        'metrics.wired_tiger.cache.tracked_dirty_pages_in_the_cache' => 0,
        'metrics.wired_tiger.cache.unmodified_pages_evicted' => 0,
        'metrics.wired_tiger.concurrent_transaction.read.available' => 128,
        'metrics.wired_tiger.concurrent_transaction.read.out' => 0,
        'metrics.wired_tiger.concurrent_transaction.read.totalTickets' => 128,
        'metrics.wired_tiger.concurrent_transaction.write.available' => 128,
        'metrics.wired_tiger.concurrent_transaction.write.out' => 0,
        'metrics.wired_tiger.concurrent_transaction.write.totalTickets' => 128,
        'metrics.wired_tiger.log.log_flush_operations' => 42_581,
        'metrics.wired_tiger.log.log_bytes_written' => 9728,
        'metrics.wired_tiger.log.log_records_compressed' => 8,
        'metrics.wired_tiger.log.log_records_not_compressed' => 7,
        'metrics.wired_tiger.log.log_sync_operations' => 11,
        'metrics.wired_tiger.log.log_write_operations' => 25,
        'metrics.wired_tiger.session.open_session_count' => 16,
        'metrics.wired_tiger.transaction.transaction_checkpoint_max_time_msecs' => 32,
        'metrics.wired_tiger.transaction.transaction_checkpoint_min_time_msecs' => 0,
        'metrics.wired_tiger.transaction.transaction_checkpoint_most_recent_time_msecs' => 0,
        'metrics.wired_tiger.transaction.transactions_committed' => 3,
        'metrics.wired_tiger.transaction.transactions_rolled_back' => 72,
        'network.bytesIn' => 4_567,
        'network.bytesOut' => 489_982,
        'network.numRequests' => 77,
        'opcounters.command' => 78,
        'opcounters.delete' => 0,
        'opcounters.getmore' => 0,
        'opcounters.insert' => 0,
        'opcounters.query' => 1,
        'opcounters.update' => 0,
        'opcountersRepl.command' => 0,
        'opcountersRepl.delete' => 0,
        'opcountersRepl.getmore' => 0,
        'opcountersRepl.insert' => 0,
        'opcountersRepl.query' => 0,
        'opcountersRepl.update' => 0
      )
    end
  end
end
