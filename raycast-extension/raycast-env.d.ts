/// <reference types="@raycast/api">

/* 🚧 🚧 🚧
 * This file is auto-generated from the extension's manifest.
 * Do not modify manually. Instead, update the `package.json` file.
 * 🚧 🚧 🚧 */

/* eslint-disable @typescript-eslint/ban-types */

type ExtensionPreferences = {}

/** Preferences accessible in all the extension's commands */
declare type Preferences = ExtensionPreferences

declare namespace Preferences {
  /** Preferences accessible in the `list-jobs` command */
  export type ListJobs = ExtensionPreferences & {}
  /** Preferences accessible in the `create-job` command */
  export type CreateJob = ExtensionPreferences & {}
}

declare namespace Arguments {
  /** Arguments passed to the `list-jobs` command */
  export type ListJobs = {}
  /** Arguments passed to the `create-job` command */
  export type CreateJob = {}
}

