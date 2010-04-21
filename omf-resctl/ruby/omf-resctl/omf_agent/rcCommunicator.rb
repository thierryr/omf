#
# Copyright (c) 2006-2009 National ICT Australia (NICTA), Australia
#
# Copyright (c) 2004-2009 WINLAB, Rutgers University, USA
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#
#
# = rcCommunicator.rb
#
# == Description
#
# This file implements a Publish/Subscribe Communicator for the Node Agent.
# This PubSub communicator is based on XMPP. 
# This current implementation uses the library XMPP4R.
#
# NOTE: Extensive modification by TR from the original code from Javid
# TODO: Remove or Comment debug messages marked as 'TDEBUG'
#
require "omf-common/omfCommunicator"
require 'omf-resctl/omf_agent/agentCommands'

#
# This class defines a Communicator entity using the Publish/Subscribe paradigm.
# The Node Agent (NA) aka Resource Controller will use this Communicator to 
# send/receive messages to/from the Node Handler (EC) aka Experiment Controller
# This Communicator is based on the Singleton design pattern.
#

class RCCommunicator < OmfCommunicator

  def self.init(opts)
    super(opts)
    # RC-secific communicator initialisation...
    # 0 - set some attributes
    @@myName = opts[:comms_name]
    @@sliceID = opts[:sliceID]
    @@domain = opts[:domain]
    @@expID = nil
    # 1 - Build my address for this slice 
    @@myAddr = create_address!(:sliceID => @@sliceID, 
                              :name => @@myName, 
                              :domain => @@domain)
  end

  def create_address(opts = nil)
    if !@@expID
      error "Not enrolled in an experiment yet, thus cannot create an address!"
      return
    end
    return create_address!(:sliceID => @@sliceID, :expID => @@expID, 
                           :domain => @@domain, :name => opts[:name])
  end

  def reset
    super()
    @@expID = nil
    # Listen to my address - wait and try again until successfull
    listening = false
    while !listening
      listening = listen(@@myAddr) { |cmd| process_command(cmd) }
      debug "Cannot listen on '#{@@myAddr.to_s}' - "+
            "retrying in #{RETRY_INTERVAL} sec."
      sleep RETRY_INTERVAL
    end
    # Also listen to the generic resource address for this slice
    listening = false
    addr = create_address(:sliceID => @@sliceID, :domain => @@domain)) 
    while !listening
      listening = listen(addr)
      debug "Cannot listen on '#{addr.to_s}' - "+
            "retrying in #{RETRY_INTERVAL} sec."
      sleep RETRY_INTERVAL
    end
  end

  #
  # This method processes the command comming from another OMF entity
  #
  #  - argArray = command line parsed into an array
  #
  def process_command(cmdObj)
    return if !valid_command(cmdObj)
    debug "Processing '#{cmdObj.cmdType}' - '#{cmdObj.target}'"
    # Perform any RC-specific communicator tasks
    execute_rc_tasks(cmdObj)
    # Retrieve the command
    method = nil
    begin
      method = AgentCommands.method(cmdObj.cmdType.to_s)
    rescue Exception
      error "Cannot find a method to process the command '#{cmdObj.cmdType}'"
      errorReply("Cannot find a method to process the command", cmdObj) 
      return
    end
    # Execute the command
    begin
      reply = method.call(self, cmdObj)
    rescue Exception => err
      error "While processing the command '#{cmdObj.cmdType}'"
      error "Error: #{err}"
      error "Trace: #{err.backtrace.join("\n")}" 
      errorReply("Failed to process the command (#{err})", cmdObj) 
      return
    end
  end

  def valid_command?(cmdObj)
    # Perform some checking...
    # - Ignore commands from ourselves or another RC
    return false if OmfProtocol::rc_cmd?(cmdObj.cmdType)
    # - Ignore commands that are not known EC commands
    if !OmfProtocol::ec_cmd?(cmdObj.cmdType)
      debug "Received unknown command '#{cmdObj.cmdType}' - ignoring it!" 
      return false
    end
    # - Ignore commands for/from unknown Slice and Experiment ID
    if (cmdObj.cmdType != :ENROLL) && 
       ((cmdObj.sliceID != @@sliceID) || (cmdObj.expID != @@expID))
      debug "Received command with unknown slice and exp IDs: "+
            "'#{cmdObj.sliceID}' and '#{cmdObj.expID}' - ignoring it!" 
      return false
    end
    # - Ignore commands that are not address to us 
    # (There may be multiple space-separated targets)
    targets = cmdObj.target.split(' ') 
    isForMe = false
    targets.each { |t| 
       isForMe = true if NodeAgent.instance.agentAliases.include?(t) 
     }
     if !isForMe
       debug "Received command with unknown target '#{cmdObj.target}'"+
             " - ignoring it!" 
       return false
    end
    return true
  end

  def execute_rc_tasks(cmdObject)
    case cmdObject.cmdType
    when :ENROLL
      # Set our expID and listen to our addresses for this experiment
      if !NodeAgent.instance.enrolled
        @@expID = cmdObject.expID
        debug "Experiment ID: '#{@@expID}'"
        addrNode = create_address(:name => cmdObject.target)
        addrExp = create_address()
        if !listen(addrNode) || !listen(addrExp)
          error "Failed to Process ENROLL command!"
          error "Maybe this is an ENROLL from an old experiment - ignoring it!"
          return
        end
      else
        debug "Received ENROLL, but I am already ENROLLED! - ignoring it!"
        return
      end
    when :ALIAS
      addrAlias = create_address(:name => cmdObject.name)
      listen(addrAlias)
    end
  end

end
