# Support Table Data Architecture

This document describes the architecture and design patterns of the `support_table_data` gem, which provides a robust solution for managing static support tables (lookup tables) in ActiveRecord applications.

## Overview

The SupportTableData gem solves the common problem of managing small, canonical datasets that exist at the intersection of data and code. These support tables contain a limited number of rows with values that are often referenced in application logic, making them critical for proper application function.

## Core Components

### Main Components Overview

```mermaid
flowchart TB
    subgraph "Application Layer"
        Model[ActiveRecord Model]
        DataFiles[Data Files<br/>YAML/JSON/CSV]
    end

    subgraph "SupportTableData Gem"
        Concern[SupportTableData Module]
        Parser[File Parser]
        Sync[Data Synchronizer]
        Helpers[Helper Methods]
    end

    subgraph "Infrastructure"
        DB[(Database)]
        Rails[Rails Environment]
        Rake[Rake Tasks]
    end

    Model --> Concern
    DataFiles --> Parser
    Parser --> Sync
    Sync --> DB
    Concern --> Helpers
    Rails --> Rake
    Rake --> Sync

    style Concern fill:#e1f5fe
    style DataFiles fill:#f3e5f5
    style DB fill:#e8f5e8
```

## Data Flow Architecture

The gem follows a clear data flow pattern from static files to database records:

```mermaid
flowchart LR
    subgraph "Source Data"
        YML[YAML Files]
        JSON[JSON Files]
        CSV[CSV Files]
    end

    subgraph "Processing"
        Parse[File Parser]
        Validate[Data Validation]
        Transform[Data Transformation]
    end

    subgraph "Storage"
        Memory[In-Memory Cache]
        DB[(Database Tables)]
    end

    subgraph "Usage"
        Helpers[Helper Methods]
        Queries[Database Queries]
        Predicates[Predicate Methods]
    end

    YML --> Parse
    JSON --> Parse
    CSV --> Parse
    Parse --> Validate
    Validate --> Transform
    Transform --> Memory
    Transform --> DB
    Memory --> Helpers
    DB --> Queries
    Helpers --> Predicates

    style Parse fill:#fff3e0
    style DB fill:#e8f5e8
    style Helpers fill:#e3f2fd
```

## Class Structure

### Core Module Design

```mermaid
classDiagram
    class SupportTableData {
        +data_directory : String
        +sync_all!() : Hash
        +support_table_classes() : Array
    }

    class ActiveRecord_Model {
        +support_table_key_attribute : String
        +support_table_data_directory : String
        +add_support_table_data(path)
        +sync_table_data!() : Array
        +named_instance(name) : Record
        +instance_names() : Array
        +protected_instance?(record) : Boolean
    }

    class NamedInstanceHelpers {
        +class_name() : Record
        +class_name_question() : Boolean
        +class_name_attribute() : Value
    }

    class FileParser {
        +parse_yaml(content) : Hash
        +parse_json(content) : Hash
        +parse_csv(content) : Array
    }

    class DataSynchronizer {
        +sync_records(data) : Array
        +create_record(attributes) : Record
        +update_record(record, attributes) : Record
    }

    SupportTableData --> ActiveRecord_Model : extends
    ActiveRecord_Model --> NamedInstanceHelpers : generates
    ActiveRecord_Model --> FileParser : uses
    ActiveRecord_Model --> DataSynchronizer : uses

    note for NamedInstanceHelpers "Methods are dynamically generated based on data file content"
```

## Named Instance System

The gem's most powerful feature is its named instance system, which generates helper methods from data files:

```mermaid
flowchart TD
    subgraph "Data File Structure"
        HashData[Hash-based Data]
        ArrayData[Array-based Data]
    end

    subgraph "Method Generation"
        ClassMethods[Class Methods<br/>Status.pending]
        InstanceMethods[Instance Methods<br/>status.pending?]
        AttributeHelpers[Attribute Helpers<br/>Status.pending_id]
    end

    subgraph "Runtime Usage"
        FindRecord[Find Specific Record]
        TestRecord[Test Record Type]
        GetAttribute[Get Static Attribute]
    end

    HashData --> ClassMethods
    HashData --> InstanceMethods
    ArrayData --> ClassMethods
    ClassMethods --> FindRecord
    InstanceMethods --> TestRecord
    AttributeHelpers --> GetAttribute

    style HashData fill:#f3e5f5
    style ClassMethods fill:#e3f2fd
    style InstanceMethods fill:#e8f5e8
```

## Data Synchronization Process

The synchronization process ensures database consistency with data files:

```mermaid
sequenceDiagram
    participant App as Application
    participant Model as AR Model
    participant Parser as File Parser
    participant DB as Database

    App->>Model: sync_table_data!
    Model->>Parser: Parse data files
    Parser-->>Model: Canonical data

    Model->>DB: BEGIN TRANSACTION
    Model->>DB: Find existing records
    DB-->>Model: Current records

    loop For each record
        Model->>Model: Compare attributes
        alt Record changed
            Model->>DB: UPDATE record
        end
    end

    loop For new records
        Model->>DB: INSERT record
    end

    Model->>DB: COMMIT TRANSACTION
    Model-->>App: Changes summary
```

## File Format Support

The gem supports multiple data file formats with a unified interface:

```mermaid
flowchart LR
    subgraph "Input Formats"
        YAML[YAML<br/>*.yml, *.yaml]
        JSON[JSON<br/>*.json]
        CSV[CSV<br/>*.csv]
    end

    subgraph "Parser Layer"
        YAMLParser[YAML::safe_load]
        JSONParser[JSON::parse]
        CSVParser[CSV Parser<br/>with headers]
    end

    subgraph "Output Format"
        Hash[Hash Structure<br/>Named instances]
        Array[Array Structure<br/>Simple records]
    end

    YAML --> YAMLParser
    JSON --> JSONParser
    CSV --> CSVParser

    YAMLParser --> Hash
    YAMLParser --> Array
    JSONParser --> Hash
    JSONParser --> Array
    CSVParser --> Array

    style YAML fill:#e8f5e8
    style JSON fill:#fff3e0
    style CSV fill:#f3e5f5
```

## Dependency Resolution

The gem automatically resolves dependencies between support table models:

```mermaid
flowchart TB
    subgraph "Dependency Analysis"
        Belongs[belongs_to Associations]
        Explicit[Explicit Dependencies]
        Through[has_many :through]
    end

    subgraph "Resolution Strategy"
        Detect[Detect Dependencies]
        Sort[Topological Sort]
        Validate[Circular Detection]
    end

    subgraph "Load Order"
        Level1[Independent Models]
        Level2[Models with Dependencies]
        Level3[Join Table Models]
    end

    Belongs --> Detect
    Explicit --> Detect
    Through --> Detect

    Detect --> Sort
    Sort --> Validate
    Validate --> Level1
    Level1 --> Level2
    Level2 --> Level3

    style Detect fill:#e3f2fd
    style Sort fill:#f3e5f5
    style Level1 fill:#e8f5e8
```

## Rails Integration

The gem integrates seamlessly with Rails applications:

```mermaid
flowchart TD
    subgraph "Rails Boot Process"
        Boot[Application Boot]
        Eager[Eager Loading]
        Routes[Routes Loading]
    end

    subgraph "Gem Integration"
        Railtie[SupportTableData::Railtie]
        Tasks[Rake Tasks]
        AutoLoad[Auto Discovery]
    end

    subgraph "Development Workflow"
        Migrate[db:migrate]
        Sync[support_table_data:sync]
        Test[Test Suite Setup]
    end

    Boot --> Railtie
    Eager --> AutoLoad
    Railtie --> Tasks
    Tasks --> Sync
    Migrate --> Sync
    Sync --> Test

    style Railtie fill:#e3f2fd
    style Sync fill:#e8f5e8
    style Test fill:#fff3e0
```

## Error Handling and Validation

The gem includes comprehensive error handling:

```mermaid
flowchart TD
    subgraph "Validation Points"
        FileFormat[File Format Validation]
        DataStructure[Data Structure Validation]
        MethodNames[Method Name Validation]
        KeyAttributes[Key Attribute Validation]
    end

    subgraph "Error Types"
        ParseError[File Parse Errors]
        NameError[Method Name Conflicts]
        DataError[Data Consistency Errors]
        TransactionError[Database Transaction Errors]
    end

    subgraph "Recovery Strategies"
        Rollback[Transaction Rollback]
        ErrorReport[Detailed Error Messages]
        PartialSync[Skip Invalid Records]
    end

    FileFormat --> ParseError
    DataStructure --> DataError
    MethodNames --> NameError
    KeyAttributes --> DataError

    ParseError --> ErrorReport
    NameError --> ErrorReport
    DataError --> Rollback
    TransactionError --> Rollback

    style ParseError fill:#ffebee
    style Rollback fill:#e8f5e8
    style ErrorReport fill:#fff3e0
```

## Performance Considerations

The gem is designed for optimal performance with small datasets:

```mermaid
flowchart LR
    subgraph "Optimization Strategies"
        SmallData[Small Dataset Focus<br/>&lt; 100 records]
        Memoization[Method Memoization]
        Transaction[Atomic Transactions]
        LazyLoad[Lazy Method Generation]
    end

    subgraph "Memory Management"
        ClassVars[Class Variables]
        Mutex[Thread Safety]
        WeakRef[Weak References]
    end

    subgraph "Database Efficiency"
        BulkOps[Bulk Operations]
        IndexHints[Key Attribute Indexing]
        MinQueries[Minimize Queries]
    end

    SmallData --> ClassVars
    Memoization --> Mutex
    Transaction --> BulkOps
    LazyLoad --> WeakRef

    ClassVars --> MinQueries
    Mutex --> IndexHints
    BulkOps --> MinQueries

    style SmallData fill:#e8f5e8
    style Transaction fill:#e3f2fd
    style MinQueries fill:#fff3e0
```

## Extension Points

The gem provides several extension points for customization:

```mermaid
flowchart TB
    subgraph "Customization Options"
        KeyAttr[Custom Key Attributes]
        DataDir[Custom Data Directories]
        Parser[Custom File Parsers]
        Validation[Custom Validations]
    end

    subgraph "Integration Hooks"
        BeforeSync[Before Sync Callbacks]
        AfterSync[After Sync Callbacks]
        MethodGen[Method Generation Hooks]
        ErrorHook[Error Handling Hooks]
    end

    subgraph "External Gems"
        Cache[SupportTableCache]
        Observers[ActiveRecord Observers]
        Auditing[Auditing Gems]
    end

    KeyAttr --> BeforeSync
    DataDir --> MethodGen
    Parser --> ErrorHook
    Validation --> AfterSync

    BeforeSync --> Cache
    MethodGen --> Observers
    ErrorHook --> Auditing

    style Cache fill:#e3f2fd
    style BeforeSync fill:#f3e5f5
    style MethodGen fill:#e8f5e8
```

## Deployment Strategy

The gem follows a deployment-friendly pattern:

```mermaid
flowchart LR
    subgraph "Development"
        DevData[Dev Data Files]
        DevDB[Dev Database]
        DevTest[Test Suite]
    end

    subgraph "CI/CD Pipeline"
        Build[Build Process]
        Migration[Run Migrations]
        DataSync[Sync Support Data]
        TestRun[Run Tests]
    end

    subgraph "Production"
        ProdDB[Production Database]
        ProdData[Production Data]
        Monitor[Monitoring]
    end

    DevData --> Build
    DevDB --> Migration
    DevTest --> TestRun

    Build --> Migration
    Migration --> DataSync
    DataSync --> TestRun
    TestRun --> ProdDB

    ProdDB --> ProdData
    ProdData --> Monitor

    style DataSync fill:#e8f5e8
    style TestRun fill:#e3f2fd
    style Monitor fill:#fff3e0
```

## Best Practices

### Model Organization

```mermaid
flowchart TD
    subgraph "File Structure"
        Models[app/models/]
        DataFiles[db/support_tables/]
        Tests[spec/models/]
    end

    subgraph "Naming Conventions"
        ModelFile[status.rb]
        DataFile[statuses.yml]
        TestFile[status_spec.rb]
    end

    subgraph "Content Organization"
        Includes[Include SupportTableData]
        Config[Configure Directories]
        AddData[Add Data Files]
        Helpers[Define Helpers]
    end

    Models --> ModelFile
    DataFiles --> DataFile
    Tests --> TestFile

    ModelFile --> Includes
    DataFile --> Config
    TestFile --> AddData
    Config --> Helpers

    style ModelFile fill:#e3f2fd
    style DataFile fill:#f3e5f5
    style Includes fill:#e8f5e8
```

## Summary

The SupportTableData gem provides a comprehensive solution for managing static support tables through:

1. **Declarative Configuration**: Define support data in version-controlled files
2. **Automatic Synchronization**: Keep database records in sync with data files
3. **Generated Helper Methods**: Clean, readable code for accessing specific records
4. **Dependency Management**: Automatic resolution of inter-table dependencies
5. **Rails Integration**: Seamless integration with Rails applications and deployment workflows
6. **Type Safety**: Compile-time method generation with runtime validation
7. **Performance**: Optimized for small datasets with minimal overhead

The architecture promotes maintainable code by keeping support data close to the application logic while ensuring data consistency across environments.

<function_calls>
<invoke name="get-syntax-docs-mermaid">
<parameter name="file">flowchart.md