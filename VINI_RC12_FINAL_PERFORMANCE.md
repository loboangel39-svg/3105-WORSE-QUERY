# RC12 Final Fix — Performance

Container rediscovery in Files runs on the existing user-initiated background
queue. Library reloads remain asynchronous. No new MainActor filesystem scan,
native provider, entitlement, or engine was introduced. Mutation serialization
continues through `DevicePatchService`'s existing lock.
