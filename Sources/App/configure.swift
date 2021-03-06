//
//  configure.swift
//  
//
//  Created by Gabriel Jacoby-Cooper on 9/21/20.
//

import Vapor
import FluentSQLiteDriver
import Queues
import QueuesFluentDriver

public func configure(_ application: Application) throws {
	application.middleware.use(FileMiddleware(publicDirectory: application.directory.publicDirectory))
	application.databases.use(.sqlite(), as: .sqlite)
	application.migrations.add(CreateBuses(), CreateRoutes(), CreateStops(), JobModelMigrate())
	application.queues.use(.fluent(useSoftDeletes: false))
	application.queues.schedule(BusDownloadingJob())
		.minutely()
		.at(0)
	application.queues.schedule(RouteDownloadingJob())
		.daily()
		.at(.midnight)
	application.queues.schedule(StopDownloadingJob())
		.daily()
		.at(.midnight)
	application.queues.schedule(LocationRemovalJob())
		.everySecond()
	try application.autoMigrate()
		.wait()
	try application.queues.startInProcessJobs()
	try application.queues.startScheduledJobs()
	if let domain = ProcessInfo.processInfo.environment["domain"] {
		try application.http.server.configuration.tlsConfiguration = .forServer(
			certificateChain: [
				.certificate(
					.init(
						file: "/etc/letsencrypt/live/\(domain)/fullchain.pem",
						format: .pem
					)
				)
			],
			privateKey: .file(
				"/etc/letsencrypt/live/\(domain)/privkey.pem"
			)
		)
	}
	_ = BusDownloadingJob().run(context: application.queues.queue.context)
	_ = RouteDownloadingJob().run(context: application.queues.queue.context)
	_ = StopDownloadingJob().run(context: application.queues.queue.context)
	try routes(application)
}

protocol Mergable: Collection {
	
	mutating func merge(with: Self);
	
}
