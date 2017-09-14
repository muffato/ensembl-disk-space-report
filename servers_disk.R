#!/usr/bin/env Rscript
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

args <- commandArgs(TRUE)
data <- read.table(args[1], header=TRUE, sep="\t")

cols=c("black","mediumpurple", "blue", "green")

n_servers = dim(data)[1]
png(args[2], width=(420+50*n_servers), height=510)
par(xpd=TRUE, mar=par()$mar+c(4,0,0,5))

b <- barplot(t(as.matrix(data[,(c(5,4,3,2))])), col=cols, ylab="Disk space in Gb")
text(b, par("usr")[2] - 50, xpd=TRUE, srt=45, adj=1, labels=data[,1])

legend('topright', inset=c(-.8/n_servers,0), bty="n", xpd=TRUE, legend=rev(c("Other","MyISAM-used", "InnoDB-used", "Free")), fill=rev(cols))
dev.off()

