# RC12 Final Fix — Package reset

Package deletion removes the `.3105`, workspace, package key, origin metadata
and author marker. It does not restore destination files or silently delete
transaction backups. Reimport creates a fresh library instance when the old
package identity has active historical evidence, while destination conflicts
remain subject to the normal transaction checks.
