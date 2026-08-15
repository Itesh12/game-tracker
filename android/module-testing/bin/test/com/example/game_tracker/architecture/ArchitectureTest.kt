package com.example.game_tracker.architecture

import com.tngtech.archunit.core.importer.ClassFileImporter
import com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses
import org.junit.Test

class ArchitectureTest {

    @Test
    fun domain_must_not_import_android_framework() {
        val importedClasses = ClassFileImporter().importPackages("com.example.game_tracker.domain")
        noClasses().that().resideInAPackage("..domain..")
            .should().accessClassesThat().resideInAnyPackage("android..", "androidx..")
            .check(importedClasses)
    }
}
