allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Suprimir notas de deprecation/unchecked en todos los proyectos (incl. plugins)
gradle.projectsEvaluated {
    allprojects {
        tasks.withType<JavaCompile>().configureEach {
            options.compilerArgs.addAll(
                listOf(
                    "-nowarn",
                    "-Xlint:-deprecation",
                    "-Xlint:-unchecked",
                    "-Xlint:-options",
                    "-Xlint:-rawtypes",
                    "-Xlint:-varargs",
                ),
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
