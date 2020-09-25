import React from 'react';
import PropTypes from 'prop-types';
import path from 'path';

import {AuthorPropType} from '../prop-types';
import Octicon from '../atom/octicon';

export default class GitTabHeaderView extends React.Component {
  static propTypes = {
    committer: AuthorPropType.isRequired,

    // Workspace
    workdir: PropTypes.string,
    workdirs: PropTypes.shape({[Symbol.iterator]: PropTypes.func.isRequired}).isRequired,
    contextLocked: PropTypes.bool.isRequired,
    changingWorkDir: PropTypes.bool.isRequired,
    changingLock: PropTypes.bool.isRequired,

    // Event Handlers
    handleAvatarClick: PropTypes.func,
    handleWorkDirSelect: PropTypes.func,
    handleLockToggle: PropTypes.func,
  }

  render() {
    const lockIcon = this.props.contextLocked ? 'lock' : 'unlock';
    const lockToggleTitle = this.props.contextLocked ?
      'Change repository with the dropdown' :
      'Follow the active pane item';

    return (
      <header className="github-Project">
        {this.renderCommitter()}
        <select className="github-Project-path input-select"
          value={this.props.workdir || ''}
          onChange={this.props.handleWorkDirSelect}
          disabled={this.props.changingWorkDir}>
          {this.renderWorkDirs()}
        </select>
        <button className="github-Project-lock btn btn-small"
          onClick={this.props.handleLockToggle}
          disabled={this.props.changingLock}
          title={lockToggleTitle}>
          <Octicon icon={lockIcon} />
        </button>
      </header>
    );
  }

  renderWorkDirs() {
    const workdirs = [];
    for (const workdir of this.props.workdirs) {
      workdirs.push(<option key={workdir} value={path.normalize(workdir)}>{path.basename(workdir)}</option>);
    }
    return workdirs;
  }

  renderCommitter() {
    const email = this.props.committer.getEmail();
    const avatarUrl = this.props.committer.getAvatarUrl();
    const name = this.props.committer.getFullName();

    return (
      <button className="github-Project-avatarBtn" onClick={this.props.handleAvatarClick}>
        <img className="github-Project-avatar"
          src={avatarUrl || 'atom://github/img/avatar.svg'}
          title={`${name} ${email}`}
          alt={`${name}'s avatar`}
        />
      </button>
    );
  }
}
