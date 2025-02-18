// src/commands/data:bulk:upsert.ts

import { flags, SfdxCommand } from '@salesforce/command';
import * as fs from 'fs';
import * as path from 'path';
import { Connection } from 'jsforce';

export default class BulkUpsert extends SfdxCommand {
  public static description = 'Bulk upsert CSV files into Salesforce using the Bulk API';

  public static examples = [
    `sfdx data:bulk:upsert --csvdir path/to/csvs --sobject Account --externalid External_Id__c`
  ];

  public static flagsConfig = {
    csvdir: flags.string({
      char: 'd',
      required: true,
      description: 'Directory containing CSV files to upsert'
    }),
    sobject: flags.string({
      char: 's',
      required: true,
      description: 'Target SObject API name (e.g., Account, CustomObj__c)'
    }),
    externalid: flags.string({
      char: 'e',
      required: true,
      description: 'External ID field to use for the upsert operation'
    })
  };

  // This command requires an authenticated org
  protected static requiresUsername = true;
  protected static requiresProject = false;

  public async run(): Promise<any> {
    // Get flag values
    const csvDir = this.flags.csvdir;
    const sobject = this.flags.sobject;
    const externalId = this.flags.externalid;

    // Obtain the connection to the target org
    const connection: Connection = this.org.getConnection();

    // Read the directory and get all CSV files sorted by name
    const files = fs
      .readdirSync(csvDir)
      .filter((file) => file.endsWith('.csv'))
      .sort();

    if (files.length === 0) {
      this.ux.error(`No CSV files found in directory: ${csvDir}`);
      return;
    }

    // Process each file sequentially
    for (const file of files) {
      const filePath = path.join(csvDir, file);
      this.ux.log(`\nProcessing file: ${filePath}`);

      try {
        await this.processCsvFile(filePath, connection, sobject, externalId);
        this.ux.log(`File "${file}" processed successfully.`);
      } catch (error) {
        this.ux.error(`Error processing file "${file}": ${error}`);
      }
    }

    this.ux.log('\nBulk upsert completed.');
    return { status: 'success' };
  }

  /**
   * Processes a single CSV file by creating a Bulk API job, uploading the file,
   * and waiting for the batch to complete.
   *
   * @param filePath - The path to the CSV file.
   * @param connection - The jsforce Connection to the Salesforce org.
   * @param sobject - The target SObject API name.
   * @param extIdField - The external ID field used for upsert.
   */
  private async processCsvFile(
    filePath: string,
    connection: Connection,
    sobject: string,
    extIdField: string
  ): Promise<void> {
    // Create a Bulk API job for upsert
    const job = connection.bulk.createJob(sobject, 'upsert', { extIdField });

    // Open a stream for the CSV file
    const stream = fs.createReadStream(filePath);

    // Create a batch from the stream. This will handle reading and uploading the CSV.
    const batch = job.createBatchFromStream(stream);

    // Wrap the batch events in a promise so we can await completion.
    const batchResult = await new Promise((resolve, reject) => {
      batch.on('error', (err: any) => {
        reject(err);
      });
      batch.on('response', (results: any) => {
        resolve(results);
      });
    });

    // Log the batch results. These results contain information on each record processed.
    this.ux.log(`Batch result for file "${path.basename(filePath)}": ${JSON.stringify(batchResult)}`);

    // Close the job to indicate that no more batches will be added.
    await new Promise((resolve, reject) => {
      job.close((err: any, res: any) => {
        if (err) {
          reject(err);
        } else {
          resolve(res);
        }
      });
    });
  }
}





Below is an updated explanation and sample approach on how you can modify your process to derive the SObject name from each file name and determine the external ID field based on the CSV file’s header. In addition, I’ll explain two strategies for handling many CSV files: either by letting your custom SFDX command iterate over all files or by using a Groovy (or similar) script in your Jenkins pipeline (with configuration via a build.json, if desired).

1. Deriving SObject Name and External ID from Each CSV File

A. SObject Name from File Name

Instead of passing an SObject name as a flag, you can simply extract it from the file name. For example, if your CSV file is named Account.csv or CustomObj__c.csv, you can remove the .csv extension and use that as your SObject API name.

B. Determining the External ID Field

Since the CSV file already has the external IDs populated, you need to know which column should be used as the external ID during upsert. There are a couple of ways to do this:
	•	Convention-based:
Assume that every CSV file contains a header row with a specific column name (for example, any header that contains "External_Id" or a specific name like "External_Id__c").
	•	Configuration-based:
Alternatively, if different files might use different external ID fields, you could define a mapping in a configuration file (such as a build.json) that maps SObject names (or file names) to their corresponding external ID field.

In the sample below, I’ll show a simple convention-based approach where we scan the header of the CSV file for a column that includes "External_Id".

2. Handling Many CSV Files

There are two main strategies:

A. Handling All CSV Files Within the SFDX Command

Your custom SFDX command can be written so that it:
	1.	Reads a given directory (provided via a flag such as --csvdir).
	2.	Finds all CSV files.
	3.	For each file, extracts the SObject name from the file name.
	4.	Reads the first line (header) of the CSV file to identify the external ID field.
	5.	Processes each CSV file in turn (or in parallel, if needed).

This approach bundles all logic into one command. Your Jenkins pipeline then just needs to call this one command, and it will iterate over all CSV files in the directory.

B. Using a Groovy Script in Jenkins

Alternatively, your Jenkins (or EPL) pipeline can be written in Groovy to:
	1.	Read the folder and iterate over the CSV files.
	2.	For each file, derive the SObject name (and even determine the external ID from the header if you want).
	3.	Invoke the custom SFDX command for each file, passing in the derived parameters.

This gives you flexibility at the pipeline level—for example, if you want to run jobs in parallel, add logging, or do additional orchestration. You can also use a configuration file (like build.json) to store mappings if the convention-based approach isn’t sufficient.

Example Groovy snippet (within a Jenkinsfile):

def csvDir = "path/to/csvs"
new File(csvDir).eachFileMatch(~/.*\.csv/) { file ->
    // Derive SObject name from file name (removes the .csv extension)
    def sobjectName = file.name.replaceAll(/\.csv$/, '')
    // Optionally, read the first line to determine external ID (or retrieve from build.json)
    // For now, assume a default external ID field (or you can parameterize it)
    def externalIdField = "External_Id__c"
    
    // Call your SFDX custom command (if it supports passing these values)
    sh "sfdx data:bulk:upsert --csvfile ${file.absolutePath} --sobject ${sobjectName} --externalid ${externalIdField}"
}

Note: The above snippet assumes you modify your custom command to process a single CSV file if needed. You can design your command either to handle one file at a time or process an entire directory at once.

3. Updated SFDX Command Sample (TypeScript)

Below is an updated version of the custom SFDX command that:
	•	Accepts a directory of CSV files (--csvdir).
	•	Derives the SObject name from the CSV file name.
	•	Reads the first line of each CSV file to determine the external ID field (by looking for a header that contains "External_Id").
	•	Processes all files sequentially.

// src/commands/data:bulk:upsert.ts

import { flags, SfdxCommand } from '@salesforce/command';
import * as fs from 'fs';
import * as path from 'path';
import { Connection } from 'jsforce';
import * as readline from 'readline';

export default class BulkUpsert extends SfdxCommand {
  public static description = 'Bulk upsert CSV files into Salesforce using the Bulk API by deriving SObject name and external ID field from the file itself.';

  public static examples = [
    `sfdx data:bulk:upsert --csvdir path/to/csvs`
  ];

  public static flagsConfig = {
    csvdir: flags.string({
      char: 'd',
      required: true,
      description: 'Directory containing CSV files to upsert'
    })
  };

  // This command requires an authenticated org
  protected static requiresUsername = true;
  protected static requiresProject = false;

  public async run(): Promise<any> {
    const csvDir = this.flags.csvdir;

    // Read the directory and get all CSV files sorted by name
    const files = fs
      .readdirSync(csvDir)
      .filter((file) => file.endsWith('.csv'))
      .sort();

    if (files.length === 0) {
      this.ux.error(`No CSV files found in directory: ${csvDir}`);
      return;
    }

    // Obtain the connection to the target org
    const connection: Connection = this.org.getConnection();

    // Process each CSV file
    for (const file of files) {
      const filePath = path.join(csvDir, file);
      // Derive SObject name from file name (remove .csv extension)
      const sobject = path.basename(file, '.csv');
      this.ux.log(`\nProcessing file: ${filePath} for SObject: ${sobject}`);

      try {
        // Determine the external ID field from the CSV header
        const externalId = await this.getExternalIdField(filePath);
        this.ux.log(`Determined external ID field: ${externalId}`);

        await this.processCsvFile(filePath, connection, sobject, externalId);
        this.ux.log(`File "${file}" processed successfully.`);
      } catch (error) {
        this.ux.error(`Error processing file "${file}": ${error}`);
      }
    }

    this.ux.log('\nBulk upsert completed.');
    return { status: 'success' };
  }

  /**
   * Reads the first line of the CSV file to determine the external ID field.
   * Assumes that the header row contains a column with the substring "External_Id".
   *
   * @param filePath - The path to the CSV file.
   * @returns The external ID field name.
   */
  private async getExternalIdField(filePath: string): Promise<string> {
    return new Promise<string>((resolve, reject) => {
      const stream = fs.createReadStream(filePath);
      const rl = readline.createInterface({ input: stream });
      rl.on('line', (line: string) => {
        rl.close();
        const headers = line.split(',');
        const externalIdField = headers.find((h) => h.includes('External_Id'));
        if (!externalIdField) {
          return reject(new Error(`No external ID field found in file header: ${line}`));
        }
        resolve(externalIdField.trim());
      });
      rl.on('error', (err) => reject(err));
    });
  }

  /**
   * Processes a single CSV file by creating a Bulk API job, uploading the file,
   * and waiting for the batch to complete.
   *
   * @param filePath - The path to the CSV file.
   * @param connection - The jsforce Connection to the Salesforce org.
   * @param sobject - The target SObject API name.
   * @param extIdField - The external ID field used for upsert.
   */
  private async processCsvFile(
    filePath: string,
    connection: Connection,
    sobject: string,
    extIdField: string
  ): Promise<void> {
    // Create a Bulk API job for upsert
    const job = connection.bulk.createJob(sobject, 'upsert', { extIdField });

    // Open a stream for the CSV file
    const stream = fs.createReadStream(filePath);

    // Create a batch from the stream
    const batch = job.createBatchFromStream(stream);

    // Await batch completion
    const batchResult = await new Promise((resolve, reject) => {
      batch.on('error', (err: any) => {
        reject(err);
      });
      batch.on('response', (results: any) => {
        resolve(results);
      });
    });

    // Log the batch results
    this.ux.log(`Batch result for "${path.basename(filePath)}": ${JSON.stringify(batchResult)}`);

    // Close the job
    await new Promise((resolve, reject) => {
      job.close((err: any, res: any) => {
        if (err) {
          reject(err);
        } else {
          resolve(res);
        }
      });
    });
  }
}

4. Summary
	•	Automatic Parameter Derivation:
The updated command now automatically derives the target SObject name from the CSV file’s name and determines the external ID field by reading the file’s header (using a simple convention).
	•	Handling Multiple Files:
You can choose to have the command process all CSV files in a directory, or you can delegate the iteration to a Jenkins (Groovy) script. The build.json file can be used to store mappings or configurations if your external ID field cannot be determined solely by convention.
	•	Jenkins Integration:
If you prefer to keep the command simple (handling one file at a time), your Jenkins pipeline (written in Groovy) can iterate over the CSV files and call the SFDX command for each file. Otherwise, a single call to the above command will process all files sequentially.

This flexible approach should help integrate your bulk upsert process seamlessly into your deployment pipeline. Happy coding!
