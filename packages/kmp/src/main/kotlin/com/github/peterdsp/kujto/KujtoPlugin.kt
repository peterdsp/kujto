package com.github.peterdsp.kujto

import org.gradle.api.DefaultTask
import org.gradle.api.Plugin
import org.gradle.api.Project
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.TaskAction
import java.io.File

abstract class KujtoWireTask : DefaultTask() {
    @get:Input
    var includeMemory: Boolean = false

    @TaskAction
    fun wire() {
        val root = project.rootDir
        val marker = File(root, "AGENTS.md")

        if (marker.exists()) {
            logger.lifecycle("AGENTS.md already exists in ${root.path}, leaving it")
            return
        }

        marker.writeText(
            """
            # Kujto

            This project is prepared for Kujto memory.

            Run the full installer from:
            https://github.com/peterdsp/kujto
            """.trimIndent() + "\n"
        )

        if (includeMemory) {
            File(root, "memory").mkdirs()
        }

        logger.lifecycle("Wired Kujto marker into ${root.path}")
    }
}

class KujtoPlugin : Plugin<Project> {
    override fun apply(project: Project) {
        project.tasks.register("kujtoWire", KujtoWireTask::class.java) {
            group = "kujto"
            description = "Wire a Kujto marker into this Android or KMP repository."
        }
    }
}
