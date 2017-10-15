import FluentProvider
import PostgreSQLProvider

extension Config {
    public func setup() throws {
        Node.fuzzy = [Row.self, JSON.self, Node.self]

        try setupProviders()
        try setupPreparations()
        setupMiddlewares()
    }

    private func setupProviders() throws {
        try addProvider(FluentProvider.Provider.self)
        try addProvider(PostgreSQLProvider.Provider.self)
    }

    private func setupPreparations() throws {
        preparations.append(User.self)
        preparations.append(Reminder.self)
        preparations.append(Category.self)
        preparations.append(Pivot<Reminder, Category>.self)
    }

    private func setupMiddlewares() {
        addConfigurable(middleware: GzipMiddleware(), name: "gzip")
    }
}
