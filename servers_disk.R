
args <- commandArgs(TRUE)
data <- read.table(args[1], header=TRUE, sep="\t")

cols=c("mediumpurple", "blue", "green")

n_servers = dim(data)[1]
png(args[2], width=(420+50*n_servers), height=510)
par(xpd=TRUE, mar=par()$mar+c(4,0,0,5))

b <- barplot(t(as.matrix(data[,(c(3,4,2))])), col=cols, ylab="Disk space in Gb")
text(b, par("usr")[2] - 50, xpd=TRUE, srt=45, adj=1, labels=data[,1])

legend('topright', inset=c(-.8/n_servers,0), bty="n", xpd=TRUE, legend=rev(c("MyISAM-used", "InnoDB-used", "Free")), fill=rev(cols))
dev.off()

