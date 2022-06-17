// AWS base package
package aws

import (
	"dagger.io/dagger"
	"dagger.io/dagger/core"
	"universe.dagger.io/docker"
)

_#DefaultLinuxName:       "amazonlinux"
_#DefaultLinuxVersion:    "2.0.20220121.0@sha256:f3a37f84f2644095e2c6f6fdf2bf4dbf68d5436c51afcfbfa747a5de391d5d62"
_#DefaultLinuxRepository: "index.docker.io"
_#DefaultCliVersion:      "2.4.12"

// Build provides a docker.#Image with the aws cli pre-installed to Amazon Linux 2.
// Can be customized with packages, and can be used with docker.#Run for executing custom scripts.
// Used by default with aws.#Run
#Build: {

	name:       *_#DefaultLinuxName | string
	repository: *_#DefaultLinuxRepository | string
	version:    *_#DefaultLinuxVersion | string

	docker.#Build & {
		steps: [
			docker.#Pull & {
				source: "\(repository)/\(name):\(version)"
			},
			// cache yum install separately
			docker.#Run & {
				command: {
					name: "yum"
					args: ["install", "unzip", "-y"]
				}
			},
			docker.#Run & {
				command: {
					name: "/scripts/install.sh"
					args: [version]
				}
				mounts: scripts: {
					dest:     "/scripts"
					contents: _scripts.output
				}
			},
		]
	}

	_scripts: core.#Source & {
		path: "_scripts"
	}

	// The version of the AWS CLI to install
	version: string | *_#DefaultCliVersion
}

// Credentials provides long or short-term credentials.
#Credentials: {
	// AWS access key
	accessKeyId?: dagger.#Secret

	// AWS secret key
	secretAccessKey?: dagger.#Secret

	// AWS session token (provided with temporary credentials)
	sessionToken?: dagger.#Secret

	// AWS SSO profile
	profile?: string

	// AWS Container credentials relative uri (used to automatically retrieve credentials from within AWS)
	containerCredentialsRelativeUri?: dagger.#Secret
}

// Region provides a schema to validate acceptable region value.
#Region: "us-east-2" | "us-east-1" | "us-west-1" | "us-west-2" | "af-south-1" | "ap-east-1" | "ap-southeast-3" | "ap-south-1" | "ap-northeast-3" | "ap-northeast-2" | "ap-southeast-1" | "ap-southeast-2" | "ap-northeast-1" | "ca-central-1" | "cn-north-1" | "cn-northwest-1" | "eu-central-1" | "eu-west-1" | "eu-west-2" | "eu-south-1" | "eu-west-3" | "eu-north-1" | "me-south-1" | "sa-east-1"

// Container a standalone environment pre-configured with credentials and .aws/config
#Container: {
	// _build provides the default image
	_build: #Build

	// configFile provides access to a config file, typically found in ~/.aws/config
	configFile?: dagger.#FS

	// configFolder provides access to the aws config folder, typically found in ~/.aws
	configFolder?: dager.#FS

	// credentials provides long or short-term credentials
	credentials: #Credentials

	image: docker.#Image | *_build.output

	docker.#Run & {
		input: image

		env: {
			// pass credentials as env vars
			if credentials.accessKeyId != _|_ {
				AWS_ACCESS_KEY_ID: credentials.accessKeyId
			}

			if credentials.secretAccessKey != _|_ {
				AWS_SECRET_ACCESS_KEY: credentials.secretAccessKey
			}

			if credentials.sessionToken != _|_ {
				AWS_SESSION_TOKEN: credentials.sessionToken
			}

			if credentials.profile != _|_ {
				AWS_PROFILE: credentials.profile
			}

			if credentials.containerCredentialsRelativeUri != _|_ {
				AWS_CONTAINER_CREDENTIALS_RELATIVE_URI: credentials.containerCredentialsRelativeUri
			}
		}

		if configFile != _|_ {
			mounts: awsConfigFile: {
				contents: configFile
				dest:     "/aws"
				ro:       true
			}
			env: AWS_CONFIG_FILE: "/aws/config"
		}

		if configFile != _|_ {
			mounts: awsConfigFolder: {
				contents: configFolder
				dest:     "/aws"
				ro:       true
			}
			env: AWS_CONFIG_FILE: "/aws/config"
		}
	}
}
