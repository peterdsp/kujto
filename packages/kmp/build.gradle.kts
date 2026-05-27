import org.gradle.api.publish.maven.MavenPublication

plugins {
    `java-gradle-plugin`
    `maven-publish`
    kotlin("jvm") version "2.1.21"
}

group = "com.github.peterdsp"
version = providers.gradleProperty("kujtoVersion").orElse("0.1.0").get()

gradlePlugin {
    plugins {
        create("kujto") {
            id = "com.github.peterdsp.kujto"
            implementationClass = "com.github.peterdsp.kujto.KujtoPlugin"
            displayName = "Kujto"
            description = "Wire Kujto AI memory into Android and KMP repositories."
        }
    }
}

publishing {
    publications.withType<MavenPublication>().configureEach {
        pom {
            name.set("Kujto Gradle Plugin")
            description.set(
                "Wire Kujto AI memory into Android and Kotlin Multiplatform repositories."
            )
            url.set("https://github.com/peterdsp/kujto")
            licenses {
                license {
                    name.set("MIT License")
                    url.set("https://github.com/peterdsp/kujto/blob/main/LICENSE")
                }
            }
            developers {
                developer {
                    id.set("peterdsp")
                    name.set("Peter Dhespollari")
                    url.set("https://github.com/peterdsp")
                }
            }
            scm {
                url.set("https://github.com/peterdsp/kujto")
                connection.set("scm:git:https://github.com/peterdsp/kujto.git")
                developerConnection.set("scm:git:ssh://git@github.com/peterdsp/kujto.git")
            }
        }
    }

    repositories {
        maven {
            name = "GitHubPackages"
            url = uri("https://maven.pkg.github.com/peterdsp/kujto")
            credentials {
                username = providers.gradleProperty("gpr.user")
                    .orElse(providers.environmentVariable("GITHUB_ACTOR"))
                    .orNull
                password = providers.gradleProperty("gpr.key")
                    .orElse(providers.environmentVariable("GITHUB_TOKEN"))
                    .orNull
            }
        }
    }
}
