module main

import build_data

pub type BuildDataAction = build_data.BuildDataAction

pub fn build_data_action(name string) ?BuildDataAction {
	return build_data.build_data_action(name)
}

pub fn generate_build_data(action BuildDataAction) string {
	return build_data.generate_build_data(action)
}
