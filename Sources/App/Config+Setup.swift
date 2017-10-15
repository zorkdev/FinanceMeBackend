import FluentProvider

extension Config {
    public func setup() throws {
        Node.fuzzy = [Row.self, JSON.self, Node.self]

        try setupProviders()
        try setupPreparations()
        setupMiddlewares()
    }

    private func setupProviders() throws {
        try addProvider(FluentProvider.Provider.self)
    }

    private func setupPreparations() throws {
        preparations.append(Reminder.self)
    }

    private func setupMiddlewares() {
        addConfigurable(middleware: GzipMiddleware(), name: "gzip")
    }
}
