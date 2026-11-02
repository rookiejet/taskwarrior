#!/usr/bin/env python3
###############################################################################
#
# Copyright 2006 - 2026, Tomas Babej, Paul Beckingham, Federico Hernandez.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
# USE OR OTHER DEALINGS IN THE SOFTWARE.
#
# https://www.opensource.org/licenses/mit-license.php
#
###############################################################################

import sys
import os
import shutil
import unittest
from contextlib import contextmanager

# Ensure python finds the local simpletap module
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from basetest import Task, TestCase
from basetest.utils import SOURCE_DIR

TASKPS1 = os.path.abspath(os.path.join(SOURCE_DIR, "scripts/powershell/task.ps1"))

# Completion tests need a PowerShell interpreter; pwsh is preferred.
POWERSHELL = shutil.which("pwsh") or shutil.which("powershell")


def ps_quote(value):
    """Quote a value as a PowerShell single-quoted string"""
    return "'{0}'".format(value.replace("'", "''"))


@contextmanager
def taskps1(t):
    cmd_backup = t._command

    # Use "pwsh -File task.ps1 task" as command
    t._command = [
        POWERSHELL,
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        t.taskps1_script,
        t._command[0],
    ]
    yield

    # Restore the default "task" command
    t._command = cmd_backup


def prepare_taskps1(t):
    """Prepare task.ps1 to be used in tests"""
    taskps1 = []

    # Ensure the task binary used is the same configured for the test
    with open(TASKPS1) as fh:
        for line in fh:
            line = line.rstrip("\n")

            if line == "$TaskwarriorCompletionCommand = 'task'":
                line = "$TaskwarriorCompletionCommand = {0}".format(ps_quote(t.taskw))
            if line == "$TaskwarriorCompletionRc = ''":
                line = "$TaskwarriorCompletionRc = {0}".format(
                    ps_quote("rc:{0}".format(t.taskrc))
                )

            taskps1.append(line)

    return "\n".join(taskps1)


@unittest.skipUnless(POWERSHELL, "PowerShell (pwsh) not available")
class TestPowerShellCompletionBase(TestCase):
    def setUp(self):
        self.t = Task()

        # Used also in task.ps1 script
        self.t.config("alias.samplealias", "long")
        self.t.config("abbreviation.minimum", "5")

        self.t.taskps1_script = os.path.join(self.t.datadir, "task.ps1")

        with open(self.t.taskps1_script, "w") as taskps1:
            taskps1.write(prepare_taskps1(self.t))


class TestPowerShellCompletion(TestPowerShellCompletionBase):
    def test_aliases(self):
        """aliases should be expanded"""
        with taskps1(self.t):
            code, out, err = self.t("sampleali", timeout=60)

            self.assertIn("samplealias", out)

    def test_commands(self):
        """commands should be expanded"""
        with taskps1(self.t):
            code, out, err = self.t("m", timeout=60)

            # Expansion of 'm' should contain modify
            self.assertIn("modify", out)


class TestProject(TestPowerShellCompletionBase):
    def setUp(self):
        super(TestProject, self).setUp()

        code, out, err = self.t("add testing project expansion project:todd")
        self.assertIn("Created task 1", out)

        # Ensure project was created
        code, out, err = self.t("projects")
        self.assertIn("todd", out)

    def test_project_non_matching(self):
        """project: expansion fails on non matching attribute"""
        with taskps1(self.t):
            code, out, err = self.t("projeABC : to", timeout=60)

            self.assertNotIn("todd", out)
            self.assertNotIn("todd", err)

    def test_project_abbreviation_minimum_match(self):
        """project: expansion expanded after rc.abbreviation.minimum"""
        with taskps1(self.t):
            code, out, err = self.t("proje : to", timeout=60)

            self.assertIn("todd", out)

    def test_project_abbreviation_minimum_shorter(self):
        """project: expansion fails if shorter than rc.abbreviation.minimum"""
        with taskps1(self.t):
            code, out, err = self.t("proj : to", timeout=60)

            self.assertNotIn("todd", out)
            self.assertNotIn("todd", err)

    def test_project_combined_form(self):
        """project:value in a single word should be expanded in place"""
        with taskps1(self.t):
            code, out, err = self.t("proje:to", timeout=60)

            self.assertIn("proje:todd", out)

    def test_project(self):
        """no taskrc override messages from the completion routines"""
        with taskps1(self.t):
            # TASKRC=test.rc is passed by the test suite by default
            code, out, err = self.t("ad to", timeout=60)
            # no taskrc override message should be shown
            self.assertNotIn("override", out)
            self.assertNotIn("override", err)

    def test_gc_powershell_completion(self):
        """no gc coming from powershell completion"""

        code, out, err = self.t("add this task should be number 2 and stay number 2")
        self.assertIn("Created task 2", out)

        # NOTE: Unlike the bash completion test, the deleted-task step is left
        # out here: the taskchampion backend renumbers task IDs as soon as a
        # task is deleted, whether or not the completion routines ran.
        with taskps1(self.t):
            code, out, err = self.t("depends :", timeout=60)
            self.assertNotIn("todd", out)
            self.assertNotIn("todd", err)

        code, out, err = self.t("2 modify shouldreplacetext")
        # Success = no gc was run (task 2 was not renumbered)
        self.assertIn("shouldreplacetext", out)


if __name__ == "__main__":
    from simpletap import TAPTestRunner

    unittest.main(testRunner=TAPTestRunner())

# vim: ai sts=4 et sw=4 ft=python
