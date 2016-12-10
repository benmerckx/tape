package tape;

typedef DependencyData = {
    name: String,
    source: Source
}

@:forward
abstract Dependency(DependencyData) from DependencyData {

    public function new(name: String, source: Source)
        return {
            name: name,
            source: source
        };

}